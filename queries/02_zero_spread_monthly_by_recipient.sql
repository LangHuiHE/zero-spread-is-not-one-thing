/* ---------------------------------------------------------------------------
 * Dune query 8142735 — Zero-spread fills into Base, monthly, by RECEIVING ADDRESS
 * ---------------------------------------------------------------------------
 * Supports: article §3 (the decomposition), §4, and the two decomposed panels
 *           of figure 1. This is the query the article's central claim rests on.
 *
 * Purpose
 *   Query 8139300 splits by filler and shows that fillers do not map onto
 *   channels. This one splits by recipient, which does: a channel IS a
 *   receiving address (or a sequence of them, for Channel I, which rotated
 *   three times). Adds the columns 8139300 lacked — top origin chain and its
 *   share, token count, and non-USDC/WETH fill count, which an earlier version
 *   of this analysis silently omitted and thereby missed a third token.
 *
 * ⚠ Not exhaustive. The HAVING clause keeps rows with >= 5 fills, or >= $20k
 *   USDC, or >= 5 WETH. Over the twelve complete months this drops 233 of
 *   87,479 fills (0.27%). The figure draws that residual explicitly as
 *   "below reporting threshold" rather than folding it into a channel.
 *
 * ⚠ 2026-07 is a PARTIAL month (07-01 → 07-27) and is flagged as such in the
 *   first output column. It must not enter any month-over-month comparison.
 *   The window was extended past 2026-07-01 only to pick up Channel I's third
 *   receiving address, which appears in July.
 *
 * Self-check, written before execution: recipient 0x133243d4… should reproduce
 *   20,133 / 23,538 / 24,954 for 2026-04 / 05 / 06. It does.
 *
 * Output labels (left untranslated — they are values, not comments)
 *   '完整月' = "complete month";  '**部分月 07-01~07-27**' = "**partial month**"
 *
 * Scope
 *   Destination Base. All origin chains. All output tokens.
 *   2025-07-01 → 2026-07-28, month boundaries pinned to literal dates.
 *
 * Cost: 0.118 credits (measured)
 * ------------------------------------------------------------------------- */

WITH f AS (
    SELECT
        date_trunc('month', evt_block_date)                        AS mth,
        substr(relayer,     length(relayer)     - 19)              AS r_addr,
        substr(recipient,   length(recipient)   - 19)              AS rcp,
        substr(depositor,   length(depositor)   - 19)              AS dep,
        substr(outputToken, length(outputToken) - 19)              AS tok,
        originChainId                                              AS origin,
        contract_address                                           AS ctr,
        inputAmount
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2025-07-01'
      AND evt_block_date <  date '2026-07-28'
      AND inputAmount IS NOT NULL
      AND inputAmount = outputAmount
),
lab AS (
    SELECT
        mth, r_addr, rcp, dep, origin, ctr, tok,
        (dep = rcp)                                                AS dep_eq_rcp,
        CASE WHEN tok = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
             THEN CAST(inputAmount AS double) / 1e6  END           AS usdc_amt,
        CASE WHEN tok = 0x4200000000000000000000000000000000000006
             THEN CAST(inputAmount AS double) / 1e18 END           AS weth_amt,
        (tok NOT IN (0x833589fcd6edb6e08f4c7c32d4f71b54bda02913,
                     0x4200000000000000000000000000000000000006))  AS other_tok
    FROM f
),
per_org AS (
    SELECT mth, rcp, origin, count(*) AS n FROM lab GROUP BY 1, 2, 3
),
org AS (
    SELECT mth, rcp,
           count(*)          AS n_origins,
           max_by(origin, n) AS top_origin,
           max(n)            AS top_org_n,
           sum(n)            AS tot_org
    FROM per_org GROUP BY 1, 2
),
per_rel AS (
    SELECT mth, rcp, r_addr, count(*) AS n FROM lab GROUP BY 1, 2, 3
),
rel AS (
    SELECT mth, rcp,
           count(*)          AS n_relayers,
           max_by(r_addr, n) AS top_relayer,
           max(n)            AS top_rel_n,
           sum(n)            AS tot_rel
    FROM per_rel GROUP BY 1, 2
)
SELECT
    CASE WHEN l.mth = date '2026-07-01' THEN '**部分月 07-01~07-27**'
         ELSE '完整月' END                                          AS period_flag,
    l.mth,
    l.rcp                                                          AS recipient,
    count(*)                                                       AS n_zero,
    o.n_origins,
    o.top_origin,
    round(100.0 * o.top_org_n / o.tot_org, 1)                      AS pct_top1_origin,
    r.n_relayers,
    r.top_relayer,
    round(100.0 * r.top_rel_n / r.tot_rel, 1)                      AS pct_top1_relayer,
    count(DISTINCT l.dep)                                          AS n_depositors,
    round(100.0 * count_if(l.dep_eq_rcp) / count(*), 1)            AS pct_dep_eq_rcp,
    count(DISTINCT l.tok)                                          AS n_tokens,
    count_if(l.other_tok)                                          AS n_other_token,
    count(l.usdc_amt)                                              AS n_usdc,
    round(approx_percentile(l.usdc_amt, 0.5), 2)                   AS usdc_median,
    round(sum(l.usdc_amt), 0)                                      AS usdc_sum,
    count(l.weth_amt)                                              AS n_weth,
    round(approx_percentile(l.weth_amt, 0.5), 4)                   AS weth_median,
    count(DISTINCT l.ctr)                                          AS n_contracts
FROM lab l
JOIN org o ON l.mth = o.mth AND l.rcp = o.rcp
JOIN rel r ON l.mth = r.mth AND l.rcp = r.rcp
GROUP BY l.mth, l.rcp,
         o.n_origins, o.top_origin, o.top_org_n, o.tot_org,
         r.n_relayers, r.top_relayer, r.top_rel_n, r.tot_rel
HAVING count(*) >= 5
    OR sum(l.usdc_amt) >= 20000
    OR sum(l.weth_amt) >= 5
ORDER BY l.mth, usdc_sum DESC NULLS LAST, n_zero DESC
