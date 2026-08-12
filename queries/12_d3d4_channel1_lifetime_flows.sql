/* ---------------------------------------------------------------------------
 * Dune query 8299370 — D3+D4: Channel I relays, full lifetime, in vs out
 * ---------------------------------------------------------------------------
 * Killed the extrapolation "Channel I was always a relay". Addresses B and C
 * are lossless to the cent, every month. Address A — which carries most of the
 * channel's lifetime volume — pays out about 1.98x what it takes in, for seven
 * consecutive months, with only 9-37% of outflow reaching its own payers.
 * Also excludes one of three fee-point candidates. See article §4.
 *
 * ⚠ COST: 12.737 credits (measured) against a 0.469 anchor on the same table
 * and the same three addresses over one eleventh of the window — 27x, i.e.
 * super-linear in window length. This is the 13th recorded cost-estimate miss
 * in this project and the largest. erc20_base.evt_transfer does not scale
 * linearly with window; do not anchor on a short-window run of it.
 *
 * Run 2026-08-11, after the article's first draft.
 * The body below is verbatim as stored on Dune, including its own header.
 * ------------------------------------------------------------------------- */

/* D3 + D4 — Channel I: all three relay addresses, full lifetime, in vs out
 *
 * D3: address A (0x0000..60f6e8, 2025-10..2026-04) carries most of the channel's
 *     lifetime volume and has NEVER been traced. Everything said about "Channel I
 *     is a bridging relay" comes from B and C in 2026-07 alone, and was labelled
 *     an extrapolation rather than a measurement.
 *
 * D4: where does this bridging product charge? Three candidates were listed and
 *     none tested: a front-end fee on notional, an FX spread, or an off-chain
 *     arrangement with the filler. Only the first is visible here. If the relay
 *     is lossless — out equals in, and out lands back on the channel's own
 *     payers — then a cut taken AT THE RELAY is excluded. That does NOT locate
 *     the fee; it removes one of three candidates and leaves two that this data
 *     cannot reach. Stated in advance so the negative result is not later
 *     rewritten as if it were the goal.
 *
 * Self-checks, written BEFORE execution, both taken from the earlier single-month
 * trace (query 8144156):
 *   address C, 2026-07: in 47 transfers / $257,566 ; out 45 transfers / ~$257,560
 *   address B          : in $7,818.59 ; out $7,818.59 (equal)
 * A divergence on either is a signal about this query, not about the channel.
 *
 * [Post-run note] The AMOUNTS hit exactly ($257,566.03; $7,818.59 both sides).
 * The transfer COUNTS did not (59/54 against the expected 47/45) — because the
 * documented figures were USDC-only and this query covers all tokens. The
 * expectation was mis-specified, not the result. Recorded rather than quietly
 * dropped.
 *
 * Outbound counterparties are LEFT JOINed against each address's OWN Across
 * payers, so "the money goes back to the people who paid in" is measured per
 * address instead of inherited from B and C.
 *
 * Cost anchor: 8144156 = 0.469 for these same three addresses over 27 days.
 * This covers ~300 days, same table, same predicate, plus a payer CTE and a
 * LEFT JOIN. Window and join count both differ => anchor void. Expect a larger
 * magnitude, not a proportional number.
 *
 * ⚠ `from` / `to` are reserved words and must be double-quoted.
 * ⚠ 2026-07 is a PARTIAL month (ends 07-28) and must not enter a monthly trend.
 */
WITH payers AS (
    SELECT DISTINCT
        substr(recipient, length(recipient) - 19) AS rcp,
        substr(depositor, length(depositor) - 19) AS dep
    FROM across_v2_base.base_spokepool_evt_filledrelay
    WHERE evt_block_date >= date '2025-10-01'
      AND evt_block_date <  date '2026-07-28'
      AND inputAmount IS NOT NULL
      AND inputAmount = outputAmount
      AND substr(recipient, length(recipient) - 19) IN (
            0x000000000060f6e853447881951574cdd0663530,
            0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
            0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
),
tr AS (
    SELECT
        date_trunc('month', evt_block_date) AS mth,
        contract_address                    AS token,
        "from"                              AS af,
        "to"                                AS at,
        CAST(value AS double)               AS v
    FROM erc20_base.evt_transfer
    WHERE evt_block_date >= date '2025-10-01'
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
        mth,
        CASE WHEN af IN (0x000000000060f6e853447881951574cdd0663530,
                         0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                         0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
             THEN af ELSE at END                                   AS subject,
        CASE WHEN af IN (0x000000000060f6e853447881951574cdd0663530,
                         0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                         0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
             THEN 'out' ELSE 'in' END                              AS direction,
        CASE WHEN af IN (0x000000000060f6e853447881951574cdd0663530,
                         0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce,
                         0x505549590d0f107c65a61fd9f71f8dd3f92c393e)
             THEN at ELSE af END                                   AS counterparty,
        token, v
    FROM tr
)
SELECT
    l.mth,
    CASE l.subject
        WHEN 0x000000000060f6e853447881951574cdd0663530 THEN 'A 0x0000..60f6e8'
        WHEN 0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce THEN 'B 0xbcbb05dd'
        ELSE 'C 0x50554959' END                                    AS relay_addr,
    l.direction,
    count(*)                                                       AS n_transfers,
    count(DISTINCT l.counterparty)                                 AS n_counterparties,
    count_if(p.dep IS NOT NULL)                                    AS n_to_own_payer,
    round(100.0 * count_if(p.dep IS NOT NULL) / count(*), 1)       AS pct_own_payer,
    count(DISTINCT l.token)                                        AS n_tokens,
    round(sum(CASE WHEN l.token = 0x833589fcd6edb6e08f4c7c32d4f71b54bda02913
                   THEN l.v / 1e6 END), 2)                         AS usdc,
    round(sum(CASE WHEN l.token = 0x4200000000000000000000000000000000000006
                   THEN l.v / 1e18 END), 4)                        AS weth
FROM lab l
LEFT JOIN payers p ON p.rcp = l.subject AND p.dep = l.counterparty
GROUP BY 1, 2, 3
ORDER BY 2, 1, 3
