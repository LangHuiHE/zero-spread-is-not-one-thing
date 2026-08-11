#!/usr/bin/env python3
"""
Reproduce the figures in "Zero Spread Is Not One Thing".

Data comes from two Dune queries, both re-fetchable at ZERO credit cost via
getDuneQuery (returns SQL + latest_execution_id) then getExecutionResults.
Nothing here re-executes a query.

  query 8142735 -> zero-spread fills grouped BY RECIPIENT, monthly.
                   Channel attribution is exact: a channel IS a recipient (or a
                   sequence of recipients, for Channel I which rotated 3 times).
                   ⚠ carries a HAVING threshold (>=5 fills, or >=$20k USDC, or
                   >=5 WETH), so it is NOT exhaustive.
  query 8139300 -> zero-spread fills grouped by filler, monthly. Exhaustive.
                   Used ONLY for the monthly total line.

The gap between the two is drawn explicitly as "below reporting threshold"
rather than silently absorbed into a channel. Over 12 months it is 233 of
87,479 fills (0.27%).

Why attribution is by recipient and not by filler: fillers serve different
channels in different months (article §2), so a filler-based split does not
separate the channels. An earlier version of this figure attributed each
(month, filler) group to that group's top-1 recipient; that overstated
Channel I in 2026-02/03, where one filler group was split across channels.
That version is not used.

  python make_figures.py                 # offline, from committed snapshots
  python make_figures.py --source dune   # refresh snapshots (needs DUNE_API_KEY)
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import pathlib
import sys
from collections import defaultdict

HERE = pathlib.Path(__file__).resolve().parent
DATA = HERE / "data"
BY_RECIPIENT = DATA / "zero_spread_by_recipient.csv"
MONTHLY_TOTAL = DATA / "zero_spread_monthly_total.csv"

Q_BY_RECIPIENT = 8142735
Q_MONTHLY_TOTAL = 8139300

# A channel is defined by its receiving address. Channel I rotated three times;
# the rotation is evidenced separately by payer overlap (37 of 260 payers used two
# or more successive addresses, 2 used all three) -- see article §4.
CHANNELS = {
    "0x000000000060f6e853447881951574cdd0663530": "I · bridging relay",
    "0xbcbb05ddfe0fce5bed28a99c827f8e7c868863ce": "I · bridging relay",
    "0x505549590d0f107c65a61fd9f71f8dd3f92c393e": "I · bridging relay",
    "0x9a8f92a830a5cb89a3816e3d267cb7791c16b04d": "II · dust self-transfer",
    "0x133243d447026345c2b368d7ffe435dbe3c566eb": "III · payment funnel",
    "0x62a63f10d6a6689b90cca9acf2b3ab82f1576b86": "IV · $10 clock loop",
    "0xfb1b9d621011b47c18cc425bfbc677c28a337bc0": "IV · $10 clock loop",
    "0x0ad9bd6ed6be4bb742362e0fae721c3435f1c579": "IV · $10 clock loop",
    # Known slow-fill destinations (filled by relayer 0x0, i.e. no filler at all).
    "0x7c255279c098fdf6c3116d2becd9978002c09f4b": "slow fills (protocol)",
    "0x2022a5600f854cc3218e636239f4dfce9e5357b5": "slow fills (protocol)",
    "0xb58bb9643884abbbad64fa7ebc874c5481e5c032": "slow fills (protocol)",
}
UNCLASSIFIED = "other (small, unclassified)"
BELOW = "below reporting threshold"

ORDER = [
    "III · payment funnel",
    "IV · $10 clock loop",
    "I · bridging relay",
    "II · dust self-transfer",
    "slow fills (protocol)",
    UNCLASSIFIED,
    BELOW,
]
COLORS = {
    "III · payment funnel": "#2b6cb0",
    "IV · $10 clock loop": "#38a169",
    "I · bridging relay": "#d69e2e",
    "II · dust self-transfer": "#805ad5",
    "slow fills (protocol)": "#a0aec0",
    UNCLASSIFIED: "#e2e8f0",
    BELOW: "#feb2b2",
}


def _dune_get(path: str):
    import urllib.request
    key = os.environ.get("DUNE_API_KEY")
    if not key:
        sys.exit("DUNE_API_KEY not set; use --source snapshot to reproduce offline.")
    req = urllib.request.Request(f"https://api.dune.com/api/v1/{path}",
                                 headers={"X-Dune-API-Key": key})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def refresh() -> None:
    """Re-fetch both queries' stored results. Costs 0 credits; never re-executes."""
    DATA.mkdir(parents=True, exist_ok=True)

    meta = _dune_get(f"query/{Q_BY_RECIPIENT}")
    if not meta.get("latest_execution_id"):
        sys.exit(f"query {Q_BY_RECIPIENT} has no stored execution; refusing to spend credits.")
    rows = _dune_get(f"execution/{meta['latest_execution_id']}/results?limit=1000")["result"]["rows"]
    with BY_RECIPIENT.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["mth", "recipient", "n_zero"])
        for r in rows:
            if str(r["mth"])[:7] == "2026-07":
                continue  # partial month 07-01..07-27; must not enter a monthly series
            w.writerow([str(r["mth"])[:7], str(r["recipient"]).lower(), r["n_zero"]])

    meta = _dune_get(f"query/{Q_MONTHLY_TOTAL}")
    rows = _dune_get(f"execution/{meta['latest_execution_id']}/results?limit=1000")["result"]["rows"]
    agg = defaultdict(int)
    for r in rows:
        agg[str(r["mth"])[:7]] += r["n_zero"]
    with MONTHLY_TOTAL.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["mth", "n_zero_total"])
        for k in sorted(agg):
            w.writerow([k, agg[k]])
    print(f"refreshed snapshots from {Q_BY_RECIPIENT} and {Q_MONTHLY_TOTAL}")


def load():
    for p in (BY_RECIPIENT, MONTHLY_TOTAL):
        if not p.exists():
            sys.exit(f"missing snapshot {p}; run with --source dune first.")
    with BY_RECIPIENT.open() as f:
        rec = [(r["mth"], r["recipient"].lower(), int(r["n_zero"])) for r in csv.DictReader(f)]
    with MONTHLY_TOTAL.open() as f:
        tot = {r["mth"]: int(r["n_zero_total"]) for r in csv.DictReader(f)}
    return rec, tot


def build(rec, tot):
    months = sorted(tot)
    idx = {m: i for i, m in enumerate(months)}
    series = {c: [0] * len(months) for c in ORDER}
    for m, addr, n in rec:
        if m not in idx:
            continue
        series[CHANNELS.get(addr, UNCLASSIFIED)][idx[m]] += n
    for m, i in idx.items():
        attributed = sum(series[c][i] for c in ORDER if c != BELOW)
        series[BELOW][i] = tot[m] - attributed
    return months, series


def plot(months, series, tot, outdir: pathlib.Path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    outdir.mkdir(parents=True, exist_ok=True)
    active = [c for c in ORDER if sum(series[c]) > 0]
    totals = [tot[m] for m in months]
    lab = [m[2:] for m in months]

    fig, axes = plt.subplots(1, 3, figsize=(16.5, 4.7))

    ax = axes[0]
    ax.plot(lab, totals, marker="o", ms=4, color="#1a202c", lw=2)
    ax.set_title("1 · As usually reported\nzero-spread fills into Base, per month",
                 fontsize=10.5, loc="left", fontweight="bold")
    ax.set_ylabel("fills")
    ax.grid(alpha=.25)
    ax.tick_params(axis="x", rotation=60, labelsize=7.5)
    ax.annotate("reads as margin\ncompression", xy=(9.05, totals[9]),
                xytext=(1.2, max(totals) * .62), fontsize=8.5, color="#4a5568",
                arrowprops=dict(arrowstyle="->", color="#4a5568", lw=.9,
                                connectionstyle="arc3,rad=-.15"))

    ax = axes[1]
    ax.stackplot(lab, [series[c] for c in active], labels=active,
                 colors=[COLORS[c] for c in active], alpha=.96, edgecolor="white", lw=.4)
    ax.set_title("2 · Decomposed by receiving address\nlevels — Channel III swamps everything",
                 fontsize=10.5, loc="left", fontweight="bold")
    ax.legend(loc="upper left", fontsize=7.5, frameon=False)
    ax.grid(alpha=.25)
    ax.tick_params(axis="x", rotation=60, labelsize=7.5)

    # Share panel: the levels panel hides the first eight months entirely, which is
    # where the "single phenomenon" reading actually breaks.
    ax = axes[2]
    shares = [[100.0 * series[c][i] / totals[i] for i in range(len(months))] for c in active]
    ax.stackplot(lab, shares, colors=[COLORS[c] for c in active],
                 alpha=.96, edgecolor="white", lw=.4)
    ax.set_title("3 · Same decomposition, as share of month\ncomposition turns over three times",
                 fontsize=10.5, loc="left", fontweight="bold")
    ax.set_ylabel("% of month's zero-spread fills")
    ax.set_ylim(0, 100)
    ax.grid(alpha=.25)
    ax.tick_params(axis="x", rotation=60, labelsize=7.5)

    fig.tight_layout()
    out = outdir / "fig1_decomposition.png"
    fig.savefig(out, dpi=170, bbox_inches="tight")
    print(f"wrote {out}")

    # Print the table too: the figure must never be the only record of the numbers.
    hdr = [c.split(" ·")[0][:9] for c in active]
    print("\n" + f"{'month':9}" + "".join(f"{h:>10}" for h in hdr) + f"{'total':>10}")
    for i, m in enumerate(months):
        print(f"{m:9}" + "".join(f"{series[c][i]:>10}" for c in active) + f"{totals[i]:>10}")
    print(f"{'TOTAL':9}" + "".join(f"{sum(series[c]):>10}" for c in active)
          + f"{sum(totals):>10}")
    below = sum(series[BELOW])
    print(f"\nbelow reporting threshold: {below} of {sum(totals)} fills "
          f"({100 * below / sum(totals):.2f}%)")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source", choices=["snapshot", "dune"], default="snapshot")
    p.add_argument("--outdir", default=str(HERE))
    a = p.parse_args()
    if a.source == "dune":
        refresh()
    rec, tot = load()
    months, series = build(rec, tot)
    plot(months, series, tot, pathlib.Path(a.outdir))


if __name__ == "__main__":
    main()
