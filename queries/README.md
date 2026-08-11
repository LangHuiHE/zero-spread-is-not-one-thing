# Queries

The eight Dune queries the article's claims rest on. Each `.sql` file is the **verbatim** query
body as stored on Dune, with an English header prepended.

## Index

| File | Dune query | What it answers | Article section | Credits |
|---|---|---|---|---|
| [`01_zero_spread_monthly_by_filler.sql`](./01_zero_spread_monthly_by_filler.sql) | 8139300 | Monthly zero-spread fills split by filler, with four fingerprint columns | §2, §5, figure | 0.158 |
| [`02_zero_spread_monthly_by_recipient.sql`](./02_zero_spread_monthly_by_recipient.sql) | 8142735 | The same months split by **receiving address** — this is what actually separates the channels | §3, figure | 0.118 |
| [`03_route_split_origin_x_filler.sql`](./03_route_split_origin_x_filler.sql) | 8139274 | Zero-spread concentration by origin chain × filler, all origins | §2 | 0.157 |
| [`04_gas_cost_of_zero_spread_fills.sql`](./04_gas_cost_of_zero_spread_fills.sql) | 8144008 | Per-fill gas for zero-spread fills vs all fills | §5 | 1.478 |
| [`05_channel1_payer_overlap.sql`](./05_channel1_payer_overlap.sql) | 8144138 | Do the same payers follow Channel I across its three receiving addresses? | §4 | 0.136 |
| [`06_channel1_erc20_flow_trace.sql`](./06_channel1_erc20_flow_trace.sql) | 8144156 | Where money goes after it reaches a Channel I intermediary | §4 | 0.469 |
| [`07_channel3_vault_outflow.sql`](./07_channel3_vault_outflow.sql) | 8144276 | Is the Channel III vault a destination or a pass-through? | §3, §6 | 0.379 |
| [`08_channel3_vault_inflow_by_counterparty.sql`](./08_channel3_vault_inflow_by_counterparty.sql) | 8168061 | Who funds the Channel III vault, and what share is Across | §5, §6 | 0.988 |

Reconciliation and sampling queries are **not** included as full text — they establish the
sample's credibility rather than any claim in the article. Their IDs and scopes are listed in
[`../PROVENANCE.md`](../PROVENANCE.md): 8129261, 8129271, 8129279, 8129295, 8129300, 8129310,
8129322, 8129479, 8129540.

## Three things about these files

**1. Output labels are not translated.** Several queries emit literal strings as *column
values* — `'出'` / `'入'` (out / in), `'慢填'` (slow fill), `'**Across relayer**'` / `'非 Across'`
(Across relayer / non-Across), `'A_origin=repay(LP费=0)'`. Translating them would produce a
query that no longer matches the stored execution the article cites. They are left exactly as
they are; the English header of each file says what each label means. Query *names* and
*descriptions*, which are metadata and affect nothing, have been rewritten in English.

**2. The SQL body is verbatim and independently checkable.** Run
[`verify_against_dune.py`](./verify_against_dune.py) to re-fetch each query from Dune and diff
it against the committed file. Zero credits — it calls `getDuneQuery`, which does not execute
anything. If a file has drifted from what Dune stores, the script says so and exits non-zero.

**3. Credit costs are measured, not estimated.** In this project, cost estimates were wrong
twelve times, ten of them high — including one that was off by 47× on a query that looked
structurally identical to its anchor. The only reliable cost anchor is an exact prior run of
the same query shape on the same tables, and "shape" means table × window × filter × join
count × aggregate function × group cardinality. Change any one and the anchor is void.

## Shared gotchas, learned the hard way

- **`uba_` prefix.** V3 Across events on Ethereum and Arbitrum live in `uba_`-prefixed tables;
  Base has no such variant. Reproduced independently on two different events. This is a
  generation-specific fact — before the `uba_` era the rule inverts.
- **`bytes32` addresses.** V3 fill tables store `inputToken` / `relayer` / `recipient` /
  `depositor` as 32-byte padded values. Restore with `substr(x, length(x) - 19)` before joining
  to any address column. Skipping this produces silent all-NULL joins, not an error.
- **`fillType` is not a top-level column.** Use
  `json_extract_scalar(relayExecutionInfo, '$.fillType') = '0'` for FastFill.
- **Month boundaries are literal dates.** `now() - interval` is prohibited throughout: it makes
  results non-reproducible and silently includes an incomplete current month.
- **`from` and `to` are reserved words** in `erc20_*.evt_transfer` and must be double-quoted.
- **`tokens.erc20` symbol bridging fails silently** for Arbitrum USDT (actually `USD₮0`). Any
  cross-chain lookup by symbol needs per-token verification.
- **`erc20_*.evt_transfer` is by far the most expensive table here** — two orders of magnitude
  above the rest. Questions that do not require per-transfer verification should not touch it.
