/* ---------------------------------------------------------------------------
 * Dune query 8144276 — Channel III: is the vault a destination or a pass-through?
 * ---------------------------------------------------------------------------
 * Supports: article §3 and §6. Source of "the vault sends 0% back to its payers
 *           and 99.5% onward to Base's commerce-payments ERC3009PaymentCollector".
 *
 * Purpose
 *   The same discriminator that failed on Channel I, applied to Channel III —
 *   and here it is validated rather than assumed. Channel I looked like a
 *   payment to a third party and was economically a self-transfer. So the
 *   question "is Channel III's vault also just a waypoint?" cannot be answered
 *   by the fill event; it has to be answered by where the money goes next.
 *
 * The test is a left join against the vault's OWN payers
 *   `dep` collects every depositor who paid this vault through Across in the
 *   same window. Outbound ERC-20 transfers are then bucketed by whether the
 *   counterparty is in that set.
 *     ~100% back to payers  → pass-through; the "payment funnel" reading is
 *                             wrong and Finding B has to be rewritten.
 *     ~0% back to payers    → genuine destination; the reading stands.
 *   Both outcomes and their consequences were written down before running. The
 *   result was ~0%, so the reading stands — as a measurement, not as the
 *   default that survived because nobody tested it.
 *
 * Self-check, written before execution: inbound USDC should come close to the
 *   $2,161,654 measured independently for 2026-07 partial month. It does.
 *
 * ⚠ Scope limits that must travel with this result
 *   - 2026-07 ONLY (07-01 → 07-28), a PARTIAL month. Not extrapolable to the
 *     channel's whole life.
 *   - The downstream contract is Base public infrastructure that anyone can
 *     call. Identifying it does NOT identify the operator.
 *   - That contract's v1.0.0 was released 2026-05-07, one month AFTER the April
 *     ramp. It therefore cannot explain the ramp.
 *
 * Output labels (left untranslated — they are values, not comments)
 *   '出' = "out";  '入' = "in";
 *   '**是该金库的付款方**' = "**is a payer of this vault**";  '其他' = "other"
 *
 * ⚠ `from` and `to` are reserved words and must be double-quoted.
 *
 * Cost: 0.379 credits (measured)
 * ------------------------------------------------------------------------- */

WITH dep AS (
    SELECT DISTINCT substr(depositor, length(depositor) - 19) AS a
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2026-07-01'
      AND evt_block_date <  date '2026-07-28'
      AND inputAmount IS NOT NULL
      AND substr(recipient, length(recipient) - 19)
          = 0x133243d447026345c2b368d7ffe435dbe3c566eb
),
tr AS (
    SELECT
        contract_address       AS token,
        "from"                 AS af,
        "to"                   AS at,
        CAST(value AS double)  AS v
    FROM erc20_base.evt_transfer
    WHERE evt_block_date >= date '2026-07-01'
      AND evt_block_date <  date '2026-07-28'
      AND ("from" = 0x133243d447026345c2b368d7ffe435dbe3c566eb
        OR "to"   = 0x133243d447026345c2b368d7ffe435dbe3c566eb)
),
lab AS (
    SELECT
        CASE WHEN af = 0x133243d447026345c2b368d7ffe435dbe3c566eb
             THEN '出' ELSE '入' END                          AS direction,
        CASE WHEN af = 0x133243d447026345c2b368d7ffe435dbe3c566eb
             THEN at ELSE af END                              AS counterparty,
        token, v
    FROM tr
),
tagged AS (
    SELECT
        l.direction,
        CASE WHEN d.a IS NOT NULL THEN '**是该金库的付款方**'
             ELSE '其他' END                                   AS cp_kind,
        l.counterparty,
        l.token,
        l.v
    FROM lab l
    LEFT JOIN dep d ON d.a = l.counterparty
),
per_cp AS (
    SELECT direction, cp_kind, token, counterparty,
           count(*) AS n, sum(v) AS sv
    FROM tagged GROUP BY 1, 2, 3, 4
)
SELECT
    direction,
    cp_kind,
    token,
    count(*)                                                     AS n_counterparties,
    sum(n)                                                       AS n_transfers,
    round(sum(CASE WHEN token = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
                   THEN sv / 1e6
                   WHEN token = 0x4200000000000000000000000000000000000006
                   THEN sv / 1e18 END), 2)                       AS usdc_or_weth,
    round(sum(sv), 0)                                            AS raw_sum,
    max_by(counterparty, sv)                                     AS top_counterparty,
    round(max(sv), 0)                                            AS top_raw
FROM per_cp
GROUP BY 1, 2, 3
ORDER BY sum(sv) DESC
