/* ---------------------------------------------------------------------------
 * Dune query 8139274 — Zero-spread concentration by origin chain × filler
 * ---------------------------------------------------------------------------
 * Supports: article §2. Source of "3,541 of 3,609 on Ethereum→Base belong to one
 *           address", "two large fillers, 1,579 and 1,817 fills, zero of them
 *           zero-spread", "925 of 925 on Polygon→Base", and the independent
 *           re-derivation of the headline 41.5%.
 *
 * Purpose
 *   An earlier claim — "zero spread is a route-differentiated phenomenon" — had
 *   been inferred by arithmetic ACROSS two queries rather than measured within
 *   one. This query measures it directly, and the claim did not survive: it is
 *   two mechanisms each leaving its own route footprint, not one phenomenon
 *   that varies by route.
 *
 * Deliberately covers ALL origin chains, not just {1, 42161}. The earlier
 *   version restricted origins and then stated a conclusion about "the market",
 *   which is the recurring error of letting conclusion scope exceed query scope.
 *
 * Diagnostic columns, present so that silent absence cannot be read as zero:
 *   n_oldgen        — rows where inputAmount IS NULL (pre-V3 generation)
 *   n_ftype_null    — rows where fillType could not be extracted
 *   Both are 0 in the stored execution, which is what licenses reading
 *   n_zero_fast as complete.
 *
 * Self-check, written before execution: origin=1, filler 0x07ae8551… should
 *   reproduce 3,541. It does.
 *
 * Re-derivation of 41.5%: origin 1 n_zero_fast (3,541) + origin 42161
 *   n_zero_fast (2,593) = 6,134; 6,134 / 14,789 = 41.48%. This matches the
 *   figure obtained from the main-sample queries by a different route.
 *
 * Scope
 *   Destination Base, single SpokePool contract 0x09aea4b2…, 2026-07-20 →
 *   2026-07-27. This is the seven-day main-sample window.
 *   All origins, all tokens. Both gross-zero (n_zero_all) and FastFill-only
 *   (n_zero_fast) counts are emitted; the difference is slow fills.
 *
 * Cost: 0.157 credits (measured)
 * ------------------------------------------------------------------------- */

WITH f AS (
    SELECT
        originChainId                                                 AS origin,
        substr(relayer, length(relayer) - 19)                         AS addr,
        inputAmount,
        outputAmount,
        (inputAmount IS NULL)                                         AS old_gen,
        json_extract_scalar(relayExecutionInfo, '$.fillType')         AS ftype
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2026-07-20'
      AND evt_block_date <  date '2026-07-27'
      AND contract_address = 0x09aea4b2242abc8bb4bb78d537a67a245a7bec64
),
g AS (
    SELECT
        origin,
        addr,
        count(*)                                                          AS n_fills,
        count_if(ftype = '0')                                             AS n_fast,
        count_if(ftype IS NULL)                                           AS n_ftype_null,
        count_if(old_gen)                                                 AS n_oldgen,
        count_if(NOT old_gen AND inputAmount = outputAmount)               AS n_zero_all,
        count_if(ftype = '0' AND NOT old_gen AND inputAmount = outputAmount) AS n_zero_fast,
        count_if(ftype = '0' AND NOT old_gen)                             AS n_fast_newgen
    FROM f
    GROUP BY 1, 2
)
SELECT
    origin,
    addr,
    n_fills,
    n_fast,
    n_oldgen,
    n_ftype_null,
    n_zero_all,
    n_zero_fast,
    CASE WHEN n_fast_newgen > 0
         THEN round(100.0 * n_zero_fast / n_fast_newgen, 1) END            AS pct_zero_fast,
    round(100.0 * n_zero_all
          / NULLIF(sum(n_zero_all) OVER (PARTITION BY origin), 0), 1)      AS pct_of_origin_zero,
    sum(n_fills)    OVER (PARTITION BY origin)                             AS origin_fills,
    sum(n_zero_all) OVER (PARTITION BY origin)                             AS origin_zero
FROM g
ORDER BY origin_zero DESC, origin, n_zero_all DESC
