/* ---------------------------------------------------------------------------
 * Dune query 8144138 — Channel I: do the same payers follow the rotations?
 * ---------------------------------------------------------------------------
 * Supports: article §4. Source of "of 260 payers, 37 paid two or more and 2 paid
 *           all three, sequentially rather than concurrently".
 *
 * Purpose
 *   Channel I's receiving address changed three times:
 *     A 0x0000…60f6e8   2025-10 → 2026-04
 *     B 0xbcbb05dd…     2026-04 → 2026-06
 *     C 0x50554959…     2026-07
 *   The question is whether these are three versions of one service or three
 *   unrelated addresses that happen to share a fingerprint.
 *
 * The discriminator was chosen before running, and it is NOT the payer list.
 *   It is n_recipients_served: does any single payer appear against two or more
 *   of the three addresses? If yes, "the same users continued after the
 *   receiving address changed" follows almost directly — and it follows without
 *   touching erc20_base.evt_transfer, which for this window would have cost
 *   6.843 credits against this query's 0.136. Deciding what the discriminator
 *   looks like before deciding what columns to emit is what made that 50×
 *   difference available.
 *
 * ⚠ What this proves and does not prove
 *   Proves: the same users kept using the service across the address changes.
 *   Does NOT prove: that the three addresses share a controller. That requires
 *   a funding relationship between them, which was looked for (query 8144156)
 *   and NOT found in the July window. The article states this limit explicitly;
 *   it must travel with any use of this result.
 *
 * Reading the output: rows are ordered by n_recipients_served descending, so
 *   the answer is the shape of the top of the result, not any single row.
 *   In the stored execution: 260 rows total, 2 with n_recipients_served = 3,
 *   35 with = 2, hence 37 with >= 2.
 *
 * ⚠ 2026-07 is a partial month (window ends 07-28). Address C exists only in
 *   that partial month, so its counts are a floor, not a level.
 *
 * Scope
 *   Destination Base, zero-spread fills only, recipient pinned to the three
 *   Channel I addresses, 2025-10-01 → 2026-07-28.
 *
 * Cost: 0.136 credits (measured)
 * ------------------------------------------------------------------------- */

WITH f AS (
    SELECT
        substr(recipient,   length(recipient)   - 19)  AS rcp,
        substr(depositor,   length(depositor)   - 19)  AS dep,
        substr(outputToken, length(outputToken) - 19)  AS tok,
        originChainId                                  AS origin,
        inputAmount,
        evt_block_date
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2025-10-01'
      AND evt_block_date <  date '2026-07-28'
      AND inputAmount IS NOT NULL
      AND inputAmount = outputAmount
      AND substr(recipient, length(recipient) - 19) IN (
            0x000000000060f6e853447881951574cdd0663530,
            0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
            0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
)
SELECT
    dep                                                              AS depositor,
    count(*)                                                         AS n_fills,
    count(DISTINCT rcp)                                              AS n_recipients_served,
    count_if(rcp = 0x000000000060f6e853447881951574cdd0663530)        AS n_to_A,
    count_if(rcp = 0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce)        AS n_to_B,
    count_if(rcp = 0x505549590d0f107c65a61fd9f71f8dd3f92c393e)        AS n_to_C,
    count(DISTINCT origin)                                           AS n_origins,
    round(sum(CASE WHEN tok = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
                   THEN CAST(inputAmount AS double) / 1e6 END), 0)   AS usdc_sum,
    round(approx_percentile(CASE WHEN tok = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
                   THEN CAST(inputAmount AS double) / 1e6 END, 0.5), 2) AS usdc_median,
    min(evt_block_date)                                              AS first_seen,
    max(evt_block_date)                                              AS last_seen
FROM f
GROUP BY 1
ORDER BY n_recipients_served DESC, usdc_sum DESC NULLS LAST
