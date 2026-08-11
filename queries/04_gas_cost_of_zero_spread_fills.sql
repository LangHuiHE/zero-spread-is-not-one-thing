/* ---------------------------------------------------------------------------
 * Dune query 8144008 — Gas cost per fill, zero-spread vs all (Base, 2026-05)
 * ---------------------------------------------------------------------------
 * Supports: article §5. Source of "9.644 × 10⁻⁷ ETH vs 2.965 × 10⁻⁶ ETH,
 *           about 3.1× cheaper", and of the 26,187 cross-check.
 *
 * Purpose
 *   A mechanical consistency probe, not a claim. If zero-spread flow really is
 *   several different businesses rather than fillers competing, the flows should
 *   differ in more than one dimension. Gas per fill is a cheap independent
 *   dimension: contract-routed swaps cost far more than plain transfers.
 *
 * Method note
 *   Gas is charged per transaction, not per fill, and one transaction can carry
 *   several fills. Cost is therefore apportioned within each transaction in
 *   proportion to the fill count — that is what
 *   `gas_wei / n_fills_in_tx * n_zero_in_tx` does. Base L1 data-availability fee
 *   (`l1_fee`) is included; on an L2 it is a large share of true cost and
 *   omitting it would understate systematically.
 *
 * No USD conversion, deliberately: joining prices.minute would add cost for a
 *   ratio that is unaffected by it. Output is ETH.
 *
 * Self-check, written before execution: n_unmatched_txs must be 0, i.e. every
 *   fill transaction is found in base.transactions. It is 0. Had it not been,
 *   the per-fill averages would have been silently computed over a subset.
 *
 * Cross-check the article uses: n_zero_fills here = 26,187, which equals the
 *   2026-05 total obtained by summing query 8139300's per-filler rows. Two
 *   separately written queries, different grouping, different purpose, same
 *   integer.
 *
 * ⚠ ONE MONTH ONLY (2026-05). This was a probe intended to measure both the
 *   answer and this table's real unit cost before deciding whether to extend to
 *   nine months. It was not extended. Nothing here licenses a statement about
 *   any other month.
 *
 * ⚠ base.transactions joined against the fill table is the second most
 *   expensive shape in this project: 141,183 transactions cost 1.478 credits.
 *
 * Cost: 1.478 credits (measured)
 * ------------------------------------------------------------------------- */

WITH f AS (
    SELECT
        evt_tx_hash                                  AS h,
        count(*)                                     AS n_fills_in_tx,
        count_if(inputAmount = outputAmount)         AS n_zero_in_tx
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2026-05-01'
      AND evt_block_date <  date '2026-06-01'
      AND inputAmount IS NOT NULL
    GROUP BY 1
),
g AS (
    SELECT
        hash,
        CAST(gas_used AS double) * CAST(gas_price AS double)
            + CAST(l1_fee AS double)                 AS gas_wei
    FROM base.transactions
    WHERE block_date >= date '2026-05-01'
      AND block_date <  date '2026-06-01'
)
SELECT
    count(*)                                                             AS n_txs,
    count_if(g.gas_wei IS NULL)                                          AS n_unmatched_txs,
    sum(f.n_fills_in_tx)                                                 AS n_fills,
    sum(f.n_zero_in_tx)                                                  AS n_zero_fills,
    round(sum(g.gas_wei) / 1e18, 6)                                      AS total_eth,
    round(sum(g.gas_wei / f.n_fills_in_tx * f.n_zero_in_tx) / 1e18, 8)   AS zero_share_eth,
    round(sum(g.gas_wei / f.n_fills_in_tx * f.n_zero_in_tx) / 1e18
          / NULLIF(sum(f.n_zero_in_tx), 0), 12)                          AS eth_per_zero_fill,
    round(sum(g.gas_wei) / 1e18 / NULLIF(sum(f.n_fills_in_tx), 0), 12)   AS eth_per_fill_all
FROM f
LEFT JOIN g ON g.hash = f.h
