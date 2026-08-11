#!/usr/bin/env python3
"""
Reproduce the figure in "Zero Spread Is Not One Thing".

Data: Dune query 8298649, a DISPLAY query that assigns every zero-spread fill
landing on Base to a channel. Re-fetchable at ZERO credit cost via getDuneQuery
(returns SQL + latest_execution_id) then getExecutionResults. Nothing here
re-executes anything.

  python make_figures.py                 # offline, from the committed snapshot
  python make_figures.py --source dune   # refresh snapshot (needs DUNE_API_KEY)

--------------------------------------------------------------------------
A correction, kept here rather than quietly fixed
--------------------------------------------------------------------------
An earlier version of this figure was built from query 8142735 and classified
SLOW FILLS by recipient address — treating three known slow-fill destinations as
a proxy. That is wrong. A slow fill is defined by `relayer = 0x0`, and the two
sets are not the same: fills can reach those recipients with a real filler.
In 2026-02 the proxy counted 229 slow fills where the correct condition gives
148, an over-count of 81, with the difference landing in "other".

It surfaced only because the same decomposition was built a second time, in SQL,
for a dashboard, and the two disagreed. Neither version announced that it was
wrong. This is the recurring shape in this project: errors are found by being
made to produce the same thing through a second route, not by re-reading the
first one.

The earlier version also carried a "below reporting threshold" band, because
8142735 has a HAVING clause and is not exhaustive. Query 8298649 is exhaustive,
so that band is gone — its 233 fills are now attributed.
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
SNAPSHOT = HERE / "data" / "zero_spread_by_channel.csv"

QUERY_ID = 8298649

ORDER = [
    "III · payment funnel",
    "IV · $10 clock loop",
    "I · bridging relay",
    "II · dust self-transfer",
    "V · slow fill (protocol, no filler)",
    "other / unclassified",
]
COLORS = {
    "III · payment funnel": "#2b6cb0",
    "IV · $10 clock loop": "#38a169",
    "I · bridging relay": "#d69e2e",
    "II · dust self-transfer": "#805ad5",
    "V · slow fill (protocol, no filler)": "#a0aec0",
    "other / unclassified": "#e2e8f0",
}

# Independently produced by query 8139300, which groups by filler instead of by
# channel. If the snapshot stops reproducing these, something moved.
EXPECTED_TOTALS = {
    "2025-07": 16, "2025-08": 8, "2025-09": 82, "2025-10": 92,
    "2025-11": 375, "2025-12": 754, "2026-01": 494, "2026-02": 2097,
    "2026-03": 2812, "2026-04": 20435, "2026-05": 26187, "2026-06": 34127,
}


def refresh() -> None:
    """Re-fetch the stored result. Costs 0 credits; never re-executes."""
    import urllib.request

    key = os.environ.get("DUNE_API_KEY")
    if not key:
        sys.exit("DUNE_API_KEY not set; use --source snapshot to reproduce offline.")

    def get(path):
        req = urllib.request.Request(f"https://api.dune.com/api/v1/{path}",
                                     headers={"X-Dune-API-Key": key})
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)

    meta = get(f"query/{QUERY_ID}")
    if not meta.get("latest_execution_id"):
        sys.exit(f"query {QUERY_ID} has no stored execution; refusing to spend credits.")
    rows = get(f"execution/{meta['latest_execution_id']}/results?limit=1000")["result"]["rows"]

    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    with SNAPSHOT.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["month", "channel", "n_fills"])
        for r in sorted(rows, key=lambda r: (str(r["month"]), r["channel"])):
            w.writerow([str(r["month"])[:7], r["channel"], r["n_fills"]])
    print(f"refreshed snapshot from query {QUERY_ID} ({len(rows)} rows)")


def load():
    if not SNAPSHOT.exists():
        sys.exit(f"missing snapshot {SNAPSHOT}; run with --source dune first.")
    with SNAPSHOT.open() as f:
        return [(r["month"], r["channel"], int(r["n_fills"])) for r in csv.DictReader(f)]


def build(rows):
    months = sorted({m for m, _, _ in rows})
    idx = {m: i for i, m in enumerate(months)}
    series = {c: [0] * len(months) for c in ORDER}
    for m, ch, n in rows:
        if ch not in series:
            sys.exit(f"unknown channel label {ch!r} — the display query changed; "
                     "update ORDER/COLORS deliberately rather than adding a catch-all.")
        series[ch][idx[m]] += n
    totals = [sum(series[c][i] for c in ORDER) for i in range(len(months))]

    bad = [m for i, m in enumerate(months)
           if m in EXPECTED_TOTALS and totals[i] != EXPECTED_TOTALS[m]]
    if bad:
        sys.exit(f"SELF-CHECK FAILED: monthly totals differ from query 8139300 for {bad}. "
                 "Do not publish this figure until the disagreement is explained.")
    return months, series, totals


def plot(months, series, totals, outdir: pathlib.Path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    outdir.mkdir(parents=True, exist_ok=True)
    active = [c for c in ORDER if sum(series[c]) > 0]
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

    hdr = [c.split(" ·")[0][:9] for c in active]
    print("\n" + f"{'month':9}" + "".join(f"{h:>10}" for h in hdr) + f"{'total':>10}")
    for i, m in enumerate(months):
        print(f"{m:9}" + "".join(f"{series[c][i]:>10}" for c in active) + f"{totals[i]:>10}")
    print(f"{'TOTAL':9}" + "".join(f"{sum(series[c]):>10}" for c in active)
          + f"{sum(totals):>10}")
    print("\nself-check vs query 8139300: all twelve monthly totals match.")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source", choices=["snapshot", "dune"], default="snapshot")
    p.add_argument("--outdir", default=str(HERE))
    a = p.parse_args()
    if a.source == "dune":
        refresh()
    plot(*build(load()), outdir=pathlib.Path(a.outdir))


if __name__ == "__main__":
    main()
