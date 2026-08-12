/* ---------------------------------------------------------------------------
 * Dune query 8299327 — D1: is the cross-channel link a cluster or a factory?
 * ---------------------------------------------------------------------------
 * Killed a finding that had already been written into the article. Result:
 * 173 contracts, only one of them in the cluster, and one of them is the Across
 * Base SpokePool itself — the contract every fill in this analysis is decoded
 * from. The shared-deployer link is dead. See article §5.
 *
 * Run 2026-08-11, after the article's first draft. Cost 0.178 credits (measured).
 * The body below is verbatim as stored on Dune, including its own header.
 * ------------------------------------------------------------------------- */

/* D1 — deployer profile for the Channel II operator 0x9a8f92a8…
 *
 * Discriminator, written down BEFORE execution (carried over verbatim from the
 * project's candidate notes, where it was pre-registered and never run):
 *
 *     ~3 contracts, all inside the cluster  => link is strong
 *     ~thousands                            => it is a deployment factory,
 *                                              and the link is worth nothing
 *
 * Neither outcome is the one being hoped for; both were written down first.
 *
 * Added here, not in the pre-registered version: flags for whether this same
 * address deployed the Channel III vault itself, or the filler that serves it.
 * Either would upgrade the link from "deployed a counterparty" to "deployed
 * the infrastructure".
 *
 * Scope: Base, full history. No date filter — the predicate is a single
 * address. Cost anchor: the nearest prior query on this table cost 1.365, but
 * it filtered on `address` (the created contract) and also unioned
 * contracts.contract_mapping, which spans 12 chains with no partition column.
 * This one filters on `"from"` and drops the union. Predicate column and join
 * count both differ => anchor void. Read the result as a magnitude.
 *
 * ⚠ `from` is a reserved word and must be double-quoted.
 */
SELECT
    count(*)                                                          AS n_deployments,
    count(DISTINCT address)                                           AS n_distinct_contracts,
    min(block_time)                                                   AS first_deploy,
    max(block_time)                                                   AS last_deploy,
    count_if(address = 0x8deda155e446f5d90579c3dce560e5b00e93f773)    AS deployed_ch3_counterparty,
    count_if(address = 0x133243d447026345c2b368d7ffe435dbe3c566eb)    AS deployed_ch3_vault,
    count_if(address = 0x07ae8551be970cb1cca11dd7a11f47ae82e70e67)    AS deployed_ch3_filler,
    count_if(address = 0x000000000060f6e853447881951574cdd0663530)    AS deployed_ch1_relay_a,
    count_if(address = 0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce)    AS deployed_ch1_relay_b,
    count_if(address = 0x505549590d0f107c65a61fd9f71f8dd3f92c393e)    AS deployed_ch1_relay_c,
    count_if(address = 0x62a63f10d6a6689b90cca9acf2b3ab82f1576b86)    AS deployed_ch4_recipient,
    round(avg(CAST(length(code) AS double)), 0)                       AS mean_code_bytes,
    slice(array_agg(CAST(address AS varchar) ORDER BY block_time), 1, 30) AS first_30_contracts
FROM base.creation_traces
WHERE "from" = 0x9a8f92a830a5cb89a3816e3d267cb7791c16b04d
