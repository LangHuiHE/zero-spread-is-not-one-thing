# Zero Spread Is Not One Thing

Decomposing a cross-chain intent metric on Across V3 / ERC-7683.

41.5% of fills in a seven-day Base sample settle at exactly zero gross spread, and the monthly
count runs 16 → 34,127 over a year. That reads as solver margins being competed to zero. It
isn't. It is four unrelated businesses plus a protocol artifact, all emitting the same on-chain
signature, and the mixture turns over three times in twelve months.

**→ [Read the article](./zero-spread-is-not-one-thing.md)**

**→ [Live charts on Dune](https://dune.com/l44l9753/zero-spread-is-not-one-thing-across-v3-channel-decomposition)**

---

## Contents

| | |
|---|---|
| [`zero-spread-is-not-one-thing.md`](./zero-spread-is-not-one-thing.md) | The article. |
| [`PROVENANCE.md`](./PROVENANCE.md) | Every number in the article → the Dune query that produced it, with the query's scope. |
| [`queries/`](./queries/) | The eight queries the article's claims rest on. SQL verbatim, English headers explaining purpose, discriminator, scope limits and measured cost. `verify_against_dune.py` re-fetches and diffs them at zero cost. |
| [`figures/make_figures.py`](./figures/make_figures.py) | Reproduces the figure, offline from committed snapshots or by re-fetching from Dune. |
| [`figures/data/`](./figures/data/) | Query-result snapshots, committed so the figure reproduces without an API key. `zero_spread_by_channel.csv` drives the figure. `zero_spread_monthly.csv` is the by-filler cut behind the table in §2. The other two are the earlier by-recipient cut, kept because disagreeing with them is what exposed a misclassification in the first version of the figure. |

## Reproducing

```bash
pip install matplotlib
python figures/make_figures.py                # offline, from committed snapshots
python figures/make_figures.py --source dune  # re-fetch (needs DUNE_API_KEY)
```

`--source dune` calls `getDuneQuery` then `getExecutionResults`. Both cost **zero credits** and
neither re-executes anything; the script refuses to run if a query has no stored execution. If
the refreshed snapshot differs from the committed one, that difference is itself a finding and
should be investigated rather than committed over.

## How this repo is organised, and why

**The authoritative source for a number is the query that produced it — never a document.**
Every layer of prose is a chance to re-summarise, and re-summarising is where this project's
recorded errors came from. One figure in an early write-up was labelled "nine months" when it
covered seven, and that error was present in the *earliest* document, then inherited by three
later ones. Checking the notes would not have caught it; re-running the query does.

So: `PROVENANCE.md` maps claims to query IDs, `figures/data/` holds committed snapshots of what
those queries returned, and the script can re-derive both at zero cost. Nothing in the article
is transcribed by hand from another document.

## Scope, stated up front

Every number comes from **Dune's decoded tables only**. Reconciliation here is
Dune-against-Dune: no block explorer, no independent RPC node, no protocol API was used as a
cross-check. All conclusions are limited to what Dune's decoders show. A systematic decoding
error would not have been caught by anything done here. This is the single largest caveat and
it applies throughout.

Further: destination chain is Base; `2026-07` is a partial month wherever it appears (01–27);
amounts may be read as lower bounds but **counts may not**, since counts here carry at least
two biases running in opposite directions with unknown net sign.

## What this project does and does not demonstrate

It is a research-and-data-reasoning project: metric decomposition, discriminator validity,
scope discipline, and reconciliation. It is **not** a software engineering showcase — there is
no service, no test suite, and no production surface here, by design.
