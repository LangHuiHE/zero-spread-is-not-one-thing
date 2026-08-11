/* ---------------------------------------------------------------------------
 * Dune query 8298649 — DISPLAY query: monthly zero-spread fills by channel
 * ---------------------------------------------------------------------------
 * Drives the figure in the article and the dashboard charts.
 *
 * ⚠ This is the one query here that is NOT evidence. It pins the receiving
 *   addresses that queries 01 and 02 established, and therefore presupposes the
 *   decomposition rather than demonstrating it. Cite 02 for the decomposition;
 *   cite this only for "what the chart shows".
 *
 * Written and run 2026-08-10, after the article. Every other query in this
 * folder predates it. Cost: 0.065 credits (measured).
 *
 * The body below is verbatim as stored on Dune, including its own header.
 * ------------------------------------------------------------------------- */

/* Display query for the dashboard — NOT an analysis query.
 *
 * ⚠ This query PINS the receiving addresses. The analysis queries (8139300,
 *   8142735) deliberately did not: pinning there would have assumed the answer.
 *   Here the channels are already established, and pinning is what makes a
 *   clean chart possible. The distinction matters — do not cite this query as
 *   evidence for the decomposition, because it presupposes it.
 *
 * Self-check, built into the output rather than kept beside it:
 *   month_total must reproduce 16, 8, 82, 92, 375, 754, 494, 2097, 2812,
 *   20435, 26187, 34127 — grand total 87,479 — independently produced by
 *   query 8139300, which groups by filler instead.
 *
 * Channel I spans all three of its successive receiving addresses.
 * Complete months only; boundaries pinned to literal dates.
 * Cost anchor: 8139300 = 0.158 on the same table, window and filter with two
 *   extra CTEs, a join, max_by and approx_percentile. Every difference here is
 *   in the cheaper direction, so expect the same order of magnitude, not a
 *   smaller number — cost estimates in this project have been wrong 12 times.
 */
WITH f AS (
    SELECT
        date_trunc('month', evt_block_date)            AS mth,
        substr(recipient,   length(recipient)   - 19)  AS rcp,
        substr(relayer,     length(relayer)     - 19)  AS r_addr,
        substr(outputToken, length(outputToken) - 19)  AS tok,
        inputAmount
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2025-07-01'
      AND evt_block_date <  date '2026-07-01'
      AND inputAmount IS NOT NULL
      AND inputAmount = outputAmount
)
SELECT
    mth                                                        AS month,
    CASE
        WHEN rcp IN (0x000000000060f6e853447881951574cdd0663530,
                     0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                     0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
             THEN 'I · bridging relay'
        WHEN rcp = 0x9a8f92a830a5cb89a3816e3d267cb7791c16b04d
             THEN 'II · dust self-transfer'
        WHEN rcp = 0x133243d447026345c2b368d7ffe435dbe3c566eb
             THEN 'III · payment funnel'
        WHEN rcp IN (0x62a63f10d6a6689b90cca9acf2b3ab82f1576b86,
                     0xfb1b9d621011b47c18cc425bfbc677c28a337bc0,
                     0x0ad9bd6ed6be4bb742362e0fae721c3435f1c579)
             THEN 'IV · $10 clock loop'
        WHEN r_addr = 0x0000000000000000000000000000000000000000
             THEN 'V · slow fill (protocol, no filler)'
        ELSE 'other / unclassified'
    END                                                        AS channel,
    count(*)                                                   AS n_fills,
    sum(count(*)) OVER (PARTITION BY mth)                      AS month_total,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY mth), 2)
                                                               AS pct_of_month,
    count(DISTINCT rcp)                                        AS n_recipients,
    round(sum(CASE WHEN tok = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
                   THEN CAST(inputAmount AS double) / 1e6 END), 0)
                                                               AS usdc_notional
FROM f
GROUP BY 1, 2
ORDER BY 1, 2
