/* ---------------------------------------------------------------------------
 * Dune query 8299358 — D2: is the 48% Across share of the vault stable?
 * ---------------------------------------------------------------------------
 * It is not. Across supplies 44.0% of the vault's USDC inflow in May 2026,
 * 73.2% in June, against 48.4% in the partial July window — a thirty-point
 * swing across three consecutive months. Killed 48.38% as a structural ratio.
 * See article §6, scope limit 1.
 *
 * Run 2026-08-11, after the article's first draft. Cost 1.330 credits (measured).
 * The body below is verbatim as stored on Dune, including its own header.
 * ------------------------------------------------------------------------- */

/* D2 — Channel III vault inflow by source, 2026-05 and 2026-06 (two COMPLETE months)
 *
 * Question: the 48.38% Across share was measured on a partial month (2026-07-01..27).
 * Is it stable? May and June were never tested.
 *
 * Self-check, written BEFORE execution:
 *   Across-side transfer counts should land close to the Channel III fill counts
 *   produced independently by query 8298649 (by-channel display): 23,538 for
 *   2026-05 and 24,954 for 2026-06. On the July window the corresponding counts
 *   matched exactly (18,798:18,798, 1:1, 3:3), so a large divergence here is a
 *   signal, not noise.
 *
 * Two counterparty counts are emitted on purpose. Raw counts on this table are
 * contaminated by address poisoning ($0 transfers from vanity look-alikes); on
 * the July window that inflated the count 7.9x. Amounts are unaffected.
 *
 * Cost anchor: the July version cost 0.988 over 27 days, but it grouped by
 * counterparty (~71 groups x 3 tokens) and used approx_percentile. This one
 * covers 61 days and groups into 2 buckets with no percentile. Window, group
 * cardinality and aggregate set all differ => anchor void; read as magnitude.
 *
 * ⚠ `from` / `to` are reserved words and must be double-quoted.
 */
WITH fills AS (
    SELECT DISTINCT substr(relayer, length(relayer) - 19) AS relayer_addr
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2026-05-01'
      AND evt_block_date <  date '2026-07-01'
      AND inputAmount IS NOT NULL
      AND json_extract_scalar(relayExecutionInfo, '$.fillType') = '0'
      AND substr(recipient, length(recipient) - 19)
          = 0x133243d447026345c2b368d7ffe435dbe3c566eb
),
inb AS (
    SELECT
        date_trunc('month', evt_block_date)                        AS mth,
        "from"                                                     AS cp,
        contract_address                                           AS token,
        CASE WHEN contract_address = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
             THEN CAST(value AS double) / 1e6 END                  AS usdc_amt,
        CAST(value AS double)                                      AS raw_val
    FROM erc20_base.evt_transfer
    WHERE evt_block_date >= date '2026-05-01'
      AND evt_block_date <  date '2026-07-01'
      AND "to" = 0x133243d447026345c2b368d7ffe435dbe3c566eb
)
SELECT
    i.mth,
    CASE WHEN f.relayer_addr IS NOT NULL THEN 'Across relayer'
         ELSE 'non-Across' END                                     AS kind,
    count(*)                                                       AS n_transfers,
    count_if(i.raw_val > 0)                                        AS n_transfers_nonzero,
    count(DISTINCT i.cp)                                           AS n_counterparties_raw,
    count(DISTINCT CASE WHEN i.raw_val > 0 THEN i.cp END)          AS n_counterparties_nonzero,
    count(DISTINCT i.token)                                        AS n_tokens,
    round(sum(i.usdc_amt), 2)                                      AS usdc_sum,
    round(100.0 * sum(i.usdc_amt)
          / sum(sum(i.usdc_amt)) OVER (PARTITION BY i.mth), 4)     AS pct_of_month_usdc,
    max_by(CAST(i.cp AS varchar), i.usdc_amt)                      AS top_counterparty
FROM inb i
LEFT JOIN fills f ON f.relayer_addr = i.cp
GROUP BY 1, 2
ORDER BY 1, 2
