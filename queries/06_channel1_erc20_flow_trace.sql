/* ---------------------------------------------------------------------------
 * Dune query 8144156 — Channel I: where the money goes after the intermediary
 * ---------------------------------------------------------------------------
 * Supports: article §4. Source of "47 in totalling $257,566 from a single
 *           source; 45 out totalling ≈$257,560 to 25 addresses, nearly all of
 *           them payers from the fill set; WETH leg 6 in / 7.71 WETH forwarded
 *           in full to one address that is itself a payer".
 *
 * Purpose
 *   This is the query that overturns the reading of Channel I. On-chain,
 *   depositor ≠ recipient in 100% of Channel I fills, every month, for nine
 *   months — which reads as payments to a third party. Following the ERC-20
 *   flow OUT of the receiving address shows the money going back to the same
 *   people who paid in. The channel is a bridging relay; economically it is a
 *   self-transfer with a contract in the middle.
 *
 * Why this had to leave the fill table
 *   The `depositor = recipient` fingerprint is computed from the fill event
 *   alone and is CORRECT on-chain and WRONG economically here. No amount of
 *   further analysis of the fill table would have revealed that. Whether a
 *   discriminator discriminates is a question about the world, not about the
 *   table.
 *
 * both_targets column flags direct transfers between the three Channel I
 *   addresses. In the stored execution there are none — which is why the
 *   article says the payer overlap proves service continuity but NOT common
 *   control. This column is the reason that limit can be stated as a
 *   measurement rather than an omission.
 *
 * ⚠ 2026-07 ONLY (07-01 → 07-28), the month of the most recent rotation.
 *   Consequences that must travel with any use of this result:
 *     - Address B had only $7,818 of residual volume by this month.
 *     - Address A, which carries most of the channel's lifetime volume, is
 *       NOT covered here at all.
 *   "Channel I was always a relay" is therefore extrapolation, not measurement.
 *   The window was deliberately not auto-expanded; cost was to be measured
 *   first and the decision to extend taken separately. It was not extended.
 *
 * Output labels (left untranslated — they are values, not comments)
 *   '出' = "out";  '入' = "in";  '**三地址间直接往来**' = "**direct transfer
 *   between the three addresses**"
 *
 * ⚠ `from` and `to` are reserved words and must be double-quoted.
 *
 * Cost: 0.469 credits (measured). erc20_base.evt_transfer is the most expensive
 *   table in this project; the address filter is what keeps this affordable —
 *   the same table over seven days without an address filter cost 6.843.
 * ------------------------------------------------------------------------- */

WITH tr AS (
    SELECT
        contract_address        AS token,
        "from"                  AS af,
        "to"                    AS at,
        CAST(value AS double)   AS v
    FROM erc20_base.evt_transfer
    WHERE evt_block_date >= date '2026-07-01'
      AND evt_block_date <  date '2026-07-28'
      AND ("from" IN (0x000000000060f6e853447881951574cdd0663530,
                      0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                      0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
        OR "to"   IN (0x000000000060f6e853447881951574cdd0663530,
                      0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                      0x505549590d0f107c65a61fd9f71f8dd3f92c393e))
),
lab AS (
    SELECT
        CASE WHEN af = 0x000000000060f6e853447881951574cdd0663530 THEN 'A 0x0000..60f6e8'
             WHEN af = 0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce THEN 'B 0xbcbb05dd'
             WHEN af = 0x505549590d0f107c65a61fd9f71f8dd3f92c393e THEN 'C 0x50554959'
             WHEN at = 0x000000000060f6e853447881951574cdd0663530 THEN 'A 0x0000..60f6e8'
             WHEN at = 0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce THEN 'B 0xbcbb05dd'
             ELSE 'C 0x50554959' END                                       AS subject,
        CASE WHEN af IN (0x000000000060f6e853447881951574cdd0663530,
                         0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                         0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
             THEN '出' ELSE '入' END                                        AS direction,
        CASE WHEN af IN (0x000000000060f6e853447881951574cdd0663530,
                         0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                         0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
             THEN at ELSE af END                                           AS counterparty,
        (af IN (0x000000000060f6e853447881951574cdd0663530,
                0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
         AND at IN (0x000000000060f6e853447881951574cdd0663530,
                    0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                    0x505549590d0f107c65a61fd9f71f8dd3f92c393e))           AS both_targets,
        token, v
    FROM tr
)
SELECT
    subject,
    direction,
    counterparty,
    token,
    CASE WHEN both_targets THEN '**三地址间直接往来**' ELSE '' END           AS flag,
    count(*)                                                               AS n_transfers,
    round(sum(CASE WHEN token = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
                   THEN v / 1e6
                   WHEN token = 0x4200000000000000000000000000000000000006
                   THEN v / 1e18 END), 2)                                  AS amt_usdc_or_weth,
    round(sum(v), 0)                                                       AS raw_sum
FROM lab
GROUP BY 1, 2, 3, 4, 5
ORDER BY sum(v) DESC
