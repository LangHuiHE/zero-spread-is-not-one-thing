# Queries

The eight Dune queries the article's claims rest on. Each `.sql` file is the **verbatim** query
body as stored on Dune, with an English header prepended.

## Index

| File | Dune query | What it answers | Article section | Credits |
|---|---|---|---|---|
| [`01_zero_spread_monthly_by_filler.sql`](./01_zero_spread_monthly_by_filler.sql) | [8139300](https://dune.com/queries/8139300) | Monthly zero-spread fills split by filler, with four fingerprint columns | §2, §5, figure | 0.158 |
| [`02_zero_spread_monthly_by_recipient.sql`](./02_zero_spread_monthly_by_recipient.sql) | [8142735](https://dune.com/queries/8142735) | The same months split by **receiving address** — this is what actually separates the channels | §3, figure | 0.118 |
| [`03_route_split_origin_x_filler.sql`](./03_route_split_origin_x_filler.sql) | [8139274](https://dune.com/queries/8139274) | Zero-spread concentration by origin chain × filler, all origins | §2 | 0.157 |
| [`04_gas_cost_of_zero_spread_fills.sql`](./04_gas_cost_of_zero_spread_fills.sql) | [8144008](https://dune.com/queries/8144008) | Per-fill gas for zero-spread fills vs all fills | §5 | 1.478 |
| [`05_channel1_payer_overlap.sql`](./05_channel1_payer_overlap.sql) | [8144138](https://dune.com/queries/8144138) | Do the same payers follow Channel I across its three receiving addresses? | §4 | 0.136 |
| [`06_channel1_erc20_flow_trace.sql`](./06_channel1_erc20_flow_trace.sql) | [8144156](https://dune.com/queries/8144156) | Where money goes after it reaches a Channel I intermediary | §4 | 0.469 |
| [`07_channel3_vault_outflow.sql`](./07_channel3_vault_outflow.sql) | [8144276](https://dune.com/queries/8144276) | Is the Channel III vault a destination or a pass-through? | §3, §6 | 0.379 |
| [`08_channel3_vault_inflow_by_counterparty.sql`](./08_channel3_vault_inflow_by_counterparty.sql) | [8168061](https://dune.com/queries/8168061) | Who funds the Channel III vault, and what share is Across | §5, §6 | 0.988 |

All nine are public on Dune — click any ID above to open, fork, or re-run it.
The dashboard built from query 09 is
[here](https://dune.com/l44l9753/zero-spread-is-not-one-thing-across-v3-channel-decomposition).

## Three that overturned earlier claims

Run after the article's first draft, each to test something the draft had asserted or
extrapolated. All three came back negative, and the article was changed.

| File | Dune query | What it killed | Credits |
|---|---|---|---|
| [`10_d1_deployer_profile.sql`](./10_d1_deployer_profile.sql) | 8299327 | The "cross-channel hard link". The shared deployer turns out to have deployed 173 contracts including the Across Base SpokePool itself — it is infrastructure, not an operator. §5 | 0.178 |
| [`11_d2_vault_inflow_may_june.sql`](./11_d2_vault_inflow_may_june.sql) | 8299358 | "48.38%" as a structural ratio. Across's share of the vault's inflow reads 44.0% / 73.2% / 48.4% across three consecutive months. §6 | 1.330 |
| [`12_d3d4_channel1_lifetime_flows.sql`](./12_d3d4_channel1_lifetime_flows.sql) | 8299370 | "Channel I was always a relay". Two of its three addresses are lossless to the cent; the third — carrying most of the volume — pays out ≈1.98× what it takes in for seven straight months. §4 | **12.737** |

⚠ Query 12 is the largest cost-estimate miss in this project: **27× its anchor**, against a
window only 11× longer, on the same table with the same address predicate.
`erc20_base.evt_transfer` does not scale linearly with window length. Do not anchor a
long-window run of it on a short-window one.

## One more, kept separate because it is a different kind of thing:

| File | Dune query | What it is | Credits |
|---|---|---|---|
| [`09_display_monthly_by_channel.sql`](./09_display_monthly_by_channel.sql) | 8298649 | **Display query.** Drives the article figure and the dashboard charts. It *pins* the receiving addresses that 01 and 02 established, and therefore presupposes the decomposition rather than demonstrating it. Cite 02 for the decomposition; cite this only for what the chart shows. | 0.065 |

Building the decomposition a second time, in SQL, is what caught an error in the
first version of the figure: it had classified slow fills by recipient address as a
proxy, where the correct condition is `relayer = 0x0`. In 2026-02 the proxy
over-counted by 81 fills. Neither version announced that it was wrong — the
disagreement did.

Reconciliation and sampling queries are **not** included as full text — they establish the
sample's credibility rather than any claim in the article. Their IDs and scopes are listed in
[`../PROVENANCE.md`](../PROVENANCE.md): 8129261, 8129271, 8129279, 8129295, 8129300, 8129310,
8129322, 8129479, 8129540.

## Three things about these files

**1. Output labels are not translated.** Several queries emit Chinese string literals as
*column values*. Translating them would produce a query that no longer matches the stored
execution the article cites, so they are left exactly as they are. Full glossary:

| Literal | Meaning | Appears in |
|---|---|---|
| `'慢填'` | slow fill (`relayer = 0x0`) | 01 |
| `'其余'` | others | 01 |
| `'完整月'` | complete month | 02 |
| `'**部分月 07-01~07-27**'` | **partial month, 07-01 to 07-27** | 02 |
| `'出'` / `'入'` | out / in | 06, 07 |
| `'**三地址间直接往来**'` | **direct transfer between the three addresses** | 06 |
| `'**是该金库的付款方**'` | **is a payer of this vault** | 07 |
| `'其他'` | other | 07, 08 |
| `'非 Across'` | non-Across | 08 |

Query *names* and *descriptions*, which are metadata and affect nothing, have been rewritten
in English.

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
