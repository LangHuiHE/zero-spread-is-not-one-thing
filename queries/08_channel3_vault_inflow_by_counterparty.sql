/* ---------------------------------------------------------------------------
 * Dune query 8168061 — Channel III: who funds the vault, and how much is Across
 * ---------------------------------------------------------------------------
 * Supports: article §5 and §6. Source of the 48.38% / 51.12% / 0.50% split, the
 *           exact attribution self-check, and the address-poisoning finding.
 *
 * Purpose
 *   Query 8144276 measured what leaves the vault. This measures what enters it,
 *   counterparty by counterparty, and left-joins each against the set of Across
 *   relayers that filled to this vault in the same window. The question it
 *   settles: what fraction of this vault's funding actually comes through
 *   Across at all?
 *
 * Answer, and why it matters: 48.38%. Slightly less than half. Any statement
 *   that treats Across fill volume as a proxy for this operator's payment
 *   volume is therefore wrong by about a factor of two — in the window measured.
 *
 * Self-check, and an unusually strong one
 *   The output shows, per Across relayer, ERC-20 transfer count against fill
 *   count: 18,798 : 18,798, 1 : 1, 3 : 3. Exactly equal, all three. The
 *   attribution in this window is exact rather than approximate — this was not
 *   designed in, it fell out of the result and is stronger than the check that
 *   was designed in. Across-side amounts likewise close exactly:
 *   $2,159,544.10 + $2,100.00 + $9.45 = $2,161,653.55.
 *
 * ⚠ ADDRESS POISONING — the reason counts from this table cannot be used raw
 *   The vault appears to have 71 inbound counterparties. 62 of them are $0
 *   transfers from vanity addresses that match the first and last four hex
 *   characters of a real counterparty — 2 bytes at each end, ~4.3 × 10⁹
 *   enumerations, GPU-minutes of work. The impersonation is visible directly in
 *   the output: real filler 0x07ae8551…0e67 sits next to 0x07ae4b09…0e67, and
 *   the payment collector 0x0E3dF951…7757 has two separate $0 impersonators.
 *   After dropping zero-value rows there are 9 real sources and the top two are
 *   99.45%. Raw counterparty counts here are inflated 7.9×.
 *   Consequence: AMOUNTS from this query may be read as lower bounds; COUNTS
 *   may not. Amount and count cannot share one caveat sentence.
 *
 * ⚠ 2026-07 ONLY (07-01 → 07-28), a PARTIAL month. May and June are untested.
 *   February, March and 1–19 April are bounded rather than untested: the 51%
 *   counterparty is a contract deployed 2026-04-20 18:14:27 UTC (query 8223421),
 *   so its share in those months is zero by construction and the Across share
 *   was higher — by an unmeasured amount.
 *
 * Output labels (left untranslated — they are values, not comments)
 *   '**Across relayer**';  '非 Across' = "non-Across";
 *   'USDC' / 'WETH' / '其他' = "other"
 *
 * ⚠ `from` and `to` are reserved words and must be double-quoted.
 *
 * Cost: 0.988 credits (measured). Note the anchor failure this shape produced:
 *   the preceding query on the same table, same window, same address filter
 *   cost 0.379. Same table + same window + same filter is NOT the same shape —
 *   this one adds a CTE against the fill table, a LEFT JOIN, approx_percentile
 *   and a three-column GROUP BY. Estimate was low by 2.6×.
 * ------------------------------------------------------------------------- */

WITH fills AS (
    SELECT
        substr(relayer, length(relayer) - 19)                     AS relayer_addr,
        CASE WHEN substr(outputToken, length(outputToken) - 19)
                  = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
             THEN CAST(outputAmount AS double) / 1e6 END          AS usdc_out
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2026-07-01'
      AND evt_block_date <  date '2026-07-28'
      AND inputAmount IS NOT NULL
      AND json_extract_scalar(relayExecutionInfo, '$.fillType') = '0'
      AND substr(recipient, length(recipient) - 19)
          = 0x133243d447026345c2b368d7ffe435dbe3c566eb
),
rel AS (
    SELECT relayer_addr,
           count(*)          AS n_fills,
           count(usdc_out)   AS n_usdc_fills,
           sum(usdc_out)     AS across_usdc
    FROM fills
    GROUP BY 1
),
inb AS (
    SELECT
        "from"            AS cp,
        contract_address  AS token,
        CASE WHEN contract_address = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913 THEN 'USDC'
             WHEN contract_address = 0x4200000000000000000000000000000000000006 THEN 'WETH'
             ELSE '其他' END                                      AS sym,
        CASE WHEN contract_address = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
             THEN CAST(value AS double) / 1e6
             WHEN contract_address = 0x4200000000000000000000000000000000000006
             THEN CAST(value AS double) / 1e18 END                AS amt,
        evt_block_time                                            AS t
    FROM erc20_base.evt_transfer
    WHERE evt_block_date >= date '2026-07-01'
      AND evt_block_date <  date '2026-07-28'
      AND "to" = 0x133243d447026345c2b368d7ffe435dbe3c566eb
)
SELECT
    i.sym,
    CASE WHEN r.relayer_addr IS NOT NULL
         THEN '**Across relayer**' ELSE '非 Across' END           AS kind,
    i.cp                                                          AS counterparty,
    count(*)                                                      AS n_transfers,
    round(sum(i.amt), 2)                                          AS amt_sum,
    round(approx_percentile(i.amt, 0.5), 4)                       AS amt_med,
    round(max(i.amt), 2)                                          AS amt_max,
    min(i.t)                                                      AS first_seen,
    max(i.t)                                                      AS last_seen,
    max(r.n_fills)                                                AS across_n_fills,
    round(max(r.across_usdc), 2)                                  AS across_usdc_to_vault
FROM inb i
LEFT JOIN rel r ON r.relayer_addr = i.cp
GROUP BY 1, 2, 3
ORDER BY CASE WHEN i.sym = 'USDC' THEN 0 ELSE 1 END, sum(i.amt) DESC
