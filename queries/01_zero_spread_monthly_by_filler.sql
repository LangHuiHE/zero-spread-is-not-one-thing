/* ---------------------------------------------------------------------------
 * Dune query 8139300 — Zero-spread fills into Base, monthly, split by filler
 * ---------------------------------------------------------------------------
 * Supports: article §2 (why splitting by filler fails), §5, and the total line
 *           in figure 1.
 *
 * Purpose
 *   Take the twelve-month zero-spread count and break it apart. The point is
 *   NOT to attribute the flow to fillers — that turns out not to work — but to
 *   emit, per (month, filler), the four fingerprints that DO separate channels:
 *     - recipient concentration  (n_recipients, pct_top1_rcp, top1_recipient)
 *     - origin-chain spread      (n_origins)
 *     - self-transfer rate       (pct_dep_eq_rcp)
 *     - amount signature         (n_exact_10usdc, usdc_median)
 *   Recipient addresses are emitted as a diagnostic column, deliberately, to
 *   answer "did the receiving address ever rotate?" — a question that cannot be
 *   asked by a query that pins addresses in its WHERE clause.
 *
 * Deliberately NOT pinned to specific recipient addresses. Fillers are labelled
 * A–F by address prefix, but classification into channels is done downstream
 * from the fingerprints. Pinning recipients here would have assumed the answer.
 *
 * Output labels (left untranslated — they are values, not comments)
 *   'A 0x07ae8551' … 'E 其余' = "E others";  'F 慢填' = "F slow fill"
 *
 * Scope
 *   Destination Base. All origin chains. All output tokens.
 *   2025-07-01 → 2026-07-01, month boundaries pinned to literal dates.
 *   `inputAmount IS NOT NULL` excludes pre-V3 rows where the field is absent —
 *   without it, a missing field in an older generation reads as "the phenomenon
 *   is new".
 *   Zero spread is defined as inputAmount = outputAmount, i.e. GROSS spread.
 *   Gas and LP fee are not deducted here.
 *
 * Cost: 0.158 credits (measured)
 * ------------------------------------------------------------------------- */

WITH f AS (
    SELECT
        date_trunc('month', evt_block_date)                       AS mth,
        substr(relayer,     length(relayer)     - 19)             AS r_addr,
        substr(recipient,   length(recipient)   - 19)             AS rcp,
        substr(depositor,   length(depositor)   - 19)             AS dep,
        substr(outputToken, length(outputToken) - 19)             AS tok,
        originChainId                                             AS origin,
        inputAmount
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2025-07-01'
      AND evt_block_date <  date '2026-07-01'
      AND inputAmount IS NOT NULL
      AND inputAmount = outputAmount
),
lab AS (
    SELECT
        mth,
        CASE
            WHEN substr(r_addr, 1, 4) = 0x07ae8551 THEN 'A 0x07ae8551'
            WHEN substr(r_addr, 1, 4) = 0x394311a6 THEN 'B 0x394311a6'
            WHEN substr(r_addr, 1, 4) = 0xfd03abca THEN 'C 0xfd03abca'
            WHEN substr(r_addr, 1, 4) = 0xd0588c94 THEN 'D 0xd0588c94'
            WHEN r_addr = 0x0000000000000000000000000000000000000000 THEN 'F 慢填'
            ELSE 'E 其余'
        END                                                        AS who,
        rcp, dep, origin, tok, inputAmount,
        (dep = rcp)                                                AS dep_eq_rcp,
        CASE WHEN tok = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
             THEN CAST(inputAmount AS double) / 1e6 END            AS usdc_amt
    FROM f
),
per_rcp AS (
    SELECT mth, who, rcp, count(*) AS n
    FROM lab GROUP BY 1, 2, 3
),
rstat AS (
    SELECT mth, who,
           count(*)       AS n_recipients,
           sum(n)         AS tot,
           max(n)         AS top_n,
           max_by(rcp, n) AS top_rcp
    FROM per_rcp GROUP BY 1, 2
)
SELECT
    l.mth,
    l.who,
    count(*)                                                      AS n_zero,
    r.n_recipients,
    round(100.0 * r.top_n / r.tot, 1)                             AS pct_top1_rcp,
    r.top_rcp                                                     AS top1_recipient,
    count(DISTINCT l.dep)                                         AS n_depositors,
    count(DISTINCT l.origin)                                      AS n_origins,
    round(100.0 * count_if(l.dep_eq_rcp) / count(*), 1)           AS pct_dep_eq_rcp,
    count_if(l.usdc_amt = 10.0)                                   AS n_exact_10usdc,
    round(approx_percentile(l.usdc_amt, 0.5), 2)                  AS usdc_median
FROM lab l
JOIN rstat r ON l.mth = r.mth AND l.who = r.who
GROUP BY l.mth, l.who, r.n_recipients, r.top_n, r.tot, r.top_rcp
ORDER BY 1, 2
