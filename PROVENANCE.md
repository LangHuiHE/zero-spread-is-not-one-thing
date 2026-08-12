# Provenance: every number in the article → the query that produced it

**Rule this file exists to enforce:** the authoritative source for a number is the query
that produced it, not any layer of prose. Prose gets re-summarised; queries do not. This
project has already shipped one number that was wrong in its *earliest* write-up and then
propagated through three later documents, so "check it against the notes" is not a control.

Every Dune query below can be re-fetched at **zero credit cost** with `getDuneQuery`
(returns SQL + latest execution id) followed by `getExecutionResults`.

**Which of these you can open, and which you cannot.** The nine queries in
[`queries/`](./queries/) are public and clickable at `dune.com/queries/<id>`:

[8139300](https://dune.com/queries/8139300) ·
[8142735](https://dune.com/queries/8142735) ·
[8139274](https://dune.com/queries/8139274) ·
[8144008](https://dune.com/queries/8144008) ·
[8144138](https://dune.com/queries/8144138) ·
[8144156](https://dune.com/queries/8144156) ·
[8144276](https://dune.com/queries/8144276) ·
[8168061](https://dune.com/queries/8168061) ·
[8298649](https://dune.com/queries/8298649) (display)

Three more from the fee-rate side investigation are public but not part of this article's
argument — they support a separate finding about where a multi-chain LP fee decline did *not*
come from: [8223421](https://dune.com/queries/8223421) ·
[8223497](https://dune.com/queries/8223497) · [8223653](https://dune.com/queries/8223653).
**8223497 in particular must be filtered on its `selfcheck` column before use**: two sides of
its identity fail to align in five of nine months, and the result set contains one orphan row
reading 8,271 bps that is not a fee rate at all.

The reconciliation and sampling IDs in the table below are **not** published. They are drafts
and self-checks, several still carrying working titles. For those, an ID is a provenance
record rather than a working link.

**A note on the published SQL.** Several of these queries emit Chinese string literals as
*column values* — `'出'` / `'入'` (out / in), `'慢填'` (slow fill), `'非 Across'` (non-Across),
`'完整月'` (complete month), `'**是该金库的付款方**'` (**is a payer of this vault**). They are
left untranslated on purpose: changing them would produce a query that no longer matches the
stored execution this analysis cites. Full glossary in
[`queries/README.md`](./queries/README.md).

---

## Sample definitions

| Name | Definition |
|---|---|
| **Main sample** | destination = Base; `originChainId` ∈ {1 (Ethereum), 42161 (Arbitrum)}; output token ∈ {USDC, WETH}; `fillType = 0` (FastFill) only; window `2026-07-20 00:00 → 2026-07-27 00:00 UTC`. **14,789 fills / $6,256,939**, = 52.3% of all Base fills in the window. Filter cascade: 28,258 → +origin 15,046 → +FastFill 14,978 → +token 14,789. |
| **12-month panel** | destination = Base; all origins; all tokens; `inputAmount IS NOT NULL AND inputAmount = outputAmount`; `2025-07-01 → 2026-07-01`. Month boundaries are pinned to literal dates — no `now() - interval` anywhere in this project. |
| **Partial month** | `2026-07-01 → 2026-07-28` is a **partial** month. It is flagged as such in query output and must not enter month-over-month comparisons. |

---

## Numbers

| # | Number as stated in the article | Query | Notes on scope |
|---|---|---|---|
| 1 | 14,789 fills / $6,256,939 / 52.3% of Base fills | 8129261, 8129271, 8129279 | Main sample. Cascade counts from 8129479 (scope-sensitivity diagnostic). |
| 2 | Deposit↔fill pairing rate **100%** (14,789 / 14,789), no LEFT JOIN fan-out | 8129295, 8129300 | Deposit-side window opened 2 days earlier than fill side; without that, spurious non-matches appear at the boundary. |
| 3 | **41.5%** zero gross spread (6,134 / 14,789) | 8139274 | Re-derived independently for this article: origin 1 `n_zero_fast` 3,541 + origin 42161 `n_zero_fast` 2,593 = 6,134; 6,134 / 14,789 = 41.48%. Matches the number originally obtained from the main-sample queries. |
| 4 | On Ethereum→Base, **3,541 of 3,609** zero-spread fills (98.1%) belong to one address | 8139274 | The remaining 68 are slow fills (`relayer = 0x0`). |
| 5 | Two large Ethereum→Base fillers posted **1,579** and **1,817** fills with **zero** zero-spread fills | 8139274 | `0x394311a6…` and `0xd0588c94…`. Demonstrates zero-spread is not a market-wide posture. |
| 6 | On Polygon→Base, **925 of 925** zero-spread fills belong to the same single address | 8139274 | 85.6% of that address's 1,080 Polygon-origin fills. |
| 7 | Monthly zero-spread fill counts, 2025-07 … 2026-06: 16, 8, 82, 92, 375, 754, 494, 2,097, 2,812, 20,435, 26,187, 34,127 (total **87,479**) | 8139300 | Summed across the `who` breakdown per month. 12-month panel. |
| 8 | Channel I: recipient `0x0000…60f6e8`, 2025-10 → 2026-04, `originChainId = 42161` in **100.0%** of months, depositor ≠ recipient **100%**, single token (USDC) | 8142735, 8139300 | Monthly rows: 48 / 259 / 569 / 426 / 425 / 83 / 10 fills; USDC median $2.93 → $17,182. |
| 9 | Channel I seven-month USDC total **$19,519,199** | 8142735 | ⚠ Address A alone, 2025-10 → 2026-04. This is **not** the $25,533,254 figure, which is the A+B family over 2025-10 → 2026-06. Two different numbers; an earlier draft merged them into one sentence and mislabelled the month count. |
| 10 | Channel I fed by **4–6 relayers per month**, top relayer only 33%–70% | 8142735 | Column `n_relayers`, `pct_top1_relayer`. |
| 11 | Channel I: **37 of 260** payers paid two or more successive recipients; **2** paid all three | 8144138 | Proves *the same users continued after the receiving address changed*. Does **not** prove the three addresses share a controller. |
| 12 | Channel I is a bridging relay: 47 inbound transfers $257,566 all from one source; 45 outbound ≈ $257,560 to 25 addresses, nearly all of them payers from the fill set. WETH leg: 6 in totalling 7.71 WETH, **fully** forwarded to a single address that is itself a payer | 8144156 | ⚠ 2026-07 only. Address B held only $7,818 residual by then; **address A was never tested**. "Channel I was always a relay" is extrapolation, not measurement. |
| 13 | Channel II: recipient `0x9a8f92a8…`, 2026-02 → 2026-07, USDC median **$0.10**, depositor = recipient **100%** | 8142735, 8139300 | |
| 14 | Channel III monthly: 52 (2026-02, median $0.01) → 1,071 / 772 payers (2026-03) → 20,133 / 9,783 payers (2026-04) → 23,538 (05) → 24,954 (06) → 18,802 partial (07) | 8142735 | ⚠ 2026-04 is a ~19× amplification of a funnel that **already existed** in March. "A phenomenon that did not previously exist" is false and was retracted. |
| 15 | Channel III inflow decomposition: Across **48.38%** ($2,161,653.55 across 18,802 transfers), non-Across `0x8deda155…` **51.12%** ($2,284,042.82 / 2,204 transfers), remaining counterparties 0.50% ($22,534.17); total $4,468,230.54 | 8168061 | Across side re-derived from the result rows: $2,159,544.10 + $2,100.00 + $9.45 = $2,161,653.55 exactly. ⚠ Stated to 2 dp, not 4: the tail is 67 rows and only the head of the result set was re-pulled, so the 4th decimal is not independently confirmed here. ⚠ Window `2026-07-01 → 07-27`, a **partial month**. |
| 16 | Of 71 apparent counterparties, **62 are address-poisoning** ($0 transfers from vanity look-alikes). After removing zero-value rows, **9** real sources, top 2 = **99.45%** | 8168061 | Vanity cost: 4 hex chars at each end = 2 bytes each end = 32 bits ≈ 4.3 × 10⁹ enumerations, GPU-minutes. Counterparty counts from ERC-20 transfer tables are a contaminated metric unless zero-value rows are dropped first. |
| 17 | Channel III vault sends **0%** back to payers and **99.5%** onward to `ERC3009PaymentCollector` | 8144276 | Contract identified by reading the Base `commerce-payments` repository and release page directly, not by label lookup. ⚠ v1.0.0 released 2026-05-07 — **one month after** the April ramp, so it cannot explain the ramp. |
| 18 | Channel IV: exactly $10.00 USDC, `originChainId = 42161` only, from 2026-05 | 8139300, 8142735 | `n_exact_10usdc` column. Recipients `0x62a63f10…`, `0xfb1b9d62…`, `0x0ad9bd6e…`. |
| 19 | Slow fills: `relayer = 0x0000…0000`, 16–154 per month | 8139300, 8142735 | `fillType ≠ 0`. Protocol mechanism, not filler behaviour. |
| 20 | Zero-spread fills cost **9.644 × 10⁻⁷ ETH** each in gas vs **2.965 × 10⁻⁶ ETH** for all fills — ~3.1× cheaper | 8144008 | ⚠ 2026-05 **only**, single month. 141,183 transactions, 141,334 fills, **0** unmatched. |
| 21 | Cross-check: 2026-05 zero-spread count = **26,187** | 8139300 **and** 8144008 | Two separately written queries, different grouping and different purpose, produce the same integer. |
| 22 | 98.04% of output tokens verifiably leave the `relayer` address; 14,789 / 14,789 fills have an exactly-matching token transfer in the same transaction; 0 amount mismatches, 0 missing transfers | 8129310, 8129322, 8129540 | |
| 23 | The 51.1% non-Across counterparty is a **contract**, deployed on Base **2026-04-20 18:14:27 UTC**, code length 36,198 bytes, deployer `0x9a8f92a8…` (= the Channel II operator) | 8223421 | `base.creation_traces` hit. Discriminator was written down **before** execution: a hit in either table is decisive for "contract"; two empty results would **not** license concluding "EOA". `contracts.contract_mapping` returned nothing — no name, no project label. |
| 24 | Therefore the 48/51 split cannot describe 2026-02, 2026-03, or 2026-04-01→19 | derived from 8223421 + 8168061 | The counterparty did not exist. Its share in those months is zero by construction; the Across share was higher by an unmeasured amount. |
| 26 | The shared deployer is a factory, not an operator: **173 contracts**, Aug 2023 → Aug 2026, only one in the cluster; it deployed neither the vault, nor its filler, nor Channel I's three relays, nor Channel IV's recipient — but it did deploy the **Across Base SpokePool** | 8299327 | Discriminator pre-registered before execution: a handful in-cluster = strong link, thousands = factory = worthless. 173 fell between; the SpokePool hit decided it. Cost 0.178. |
| 27 | Across's share of Channel III vault USDC inflow: **44.0%** (2026-05), **73.2%** (2026-06), vs 48.4% (partial 2026-07) | 8299358 | Pre-registered self-check hit exactly: Across-side transfer counts 23,538 / 24,954 equal the Channel III fill counts from 8298649. ⚠ All three are **upper bounds** on share of total value — computed on USDC only, while the non-Across side brings 14–25 tokens. Cost 1.330. |
| 28 | Channel I relay B and C are lossless (out ÷ in = **1.00×** to the cent, every month); relay A is **≈1.98×** for seven straight months with only 9–37% of outflow reaching its own payers | 8299370 | Pre-registered self-checks: B's July in/out $7,818.59 both sides — hit exactly; C's July amount $257,566.03 — hit exactly. ⚠ The pre-registered *transfer counts* (47/45) did **not** match (59/54) — those documented counts were USDC-only and this query covers all tokens; the expectation was mis-specified, not the result. Cost **12.737** against a 0.469 anchor for the same table and addresses over 1/11th the window — 27×, super-linear. |
| 25 | The figure's per-channel monthly counts, and "Channel III is 20,133 of 20,435 fills in 2026-04, 98.5%" | 8298649 | **Display query** — it pins the receiving addresses the analysis established, which the analysis queries deliberately did not. It presupposes the decomposition and must not be cited as evidence for it. Exhaustive (no HAVING threshold). Self-check is in the output: `month_total` reproduces all twelve totals from 8139300, which groups by filler instead. Cost 0.065 credits. |

---

## Self-checks that were run, and what they would have caught

| Check | Result |
|---|---|
| Deposit↔fill pairing on the main sample | 14,789 / 14,789, `depositId` unique, no fan-out |
| Channel III vault: ERC-20 transfer count vs fill count, per relayer | 18,798 : 18,798 / 1 : 1 / 3 : 3 — exact, so Across attribution in this window is exact, not approximate |
| LP-fee identity, both sides of `bundleLpFees` vs `refundAmounts` | Ethereum 315:315 across three tokens; Arbitrum 315:315 / 315:315 / 312:312; Base off by 1 |
| 2026-05 zero-spread count from two unrelated queries | 26,187 both |
| Credit ledger vs `getUsage` | Two sessions: 3.025 vs 3.027, and 0.989 vs 0.988 |

---

## Scope limits that apply to every number above

1. **Single data source.** Every number comes from Dune's decoded tables. Reconciliation in
   this project is Dune-against-Dune. No block explorer, no independent RPC node, no
   protocol API was used as a cross-check. All conclusions are therefore limited to what
   Dune's decoders show; a systematic decoding error would not have been caught.
2. **Destination is Base.** Fills into other destination chains are outside every number here.
3. **`2026-07` is a partial month** wherever it appears (01–27).
4. **Amounts may be stated as lower bounds; counts may not.** Counts here are subject to at
   least two biases running in *opposite* directions (address poisoning inflates counterparty
   counts; per-checkout derived addresses would inflate depositor counts relative to real
   users), and the net direction is unknown.
5. **Ethereum and Arbitrum V3 events live in `uba_`-prefixed tables; Base has no such
   prefix.** This is a generation-specific fact: before the `uba_` era the rule inverts.
