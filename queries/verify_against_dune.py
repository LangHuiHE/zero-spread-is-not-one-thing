#!/usr/bin/env python3
"""
Verify that the committed .sql files still match what Dune stores.

The repo claims each file's SQL body is *verbatim*. That claim needs a
mechanical check, not good intentions: the one class of error this project has
never caught by self-review is the one where a hand-carried copy quietly drifts
from its source.

  python verify_against_dune.py          # needs DUNE_API_KEY
  python verify_against_dune.py --list   # no network; just show the mapping

Cost: 0 credits. getDuneQuery fetches stored SQL and metadata; it does not
execute anything.

Exit codes: 0 all match / 1 at least one drifted or is missing / 2 setup error.
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent

# file name -> Dune query_id
QUERIES = {
    "01_zero_spread_monthly_by_filler.sql": 8139300,
    "02_zero_spread_monthly_by_recipient.sql": 8142735,
    "03_route_split_origin_x_filler.sql": 8139274,
    "04_gas_cost_of_zero_spread_fills.sql": 8144008,
    "05_channel1_payer_overlap.sql": 8144138,
    "06_channel1_erc20_flow_trace.sql": 8144156,
    "07_channel3_vault_outflow.sql": 8144276,
    "08_channel3_vault_inflow_by_counterparty.sql": 8168061,
}

HEADER = re.compile(r"\A\s*/\*.*?\*/\s*", re.DOTALL)


def body(text: str) -> str:
    """Drop the English header block this repo prepends; keep the SQL verbatim."""
    return HEADER.sub("", text).strip()


def normalise(text: str) -> str:
    """Ignore only line-ending and trailing-whitespace differences.

    Deliberately does NOT normalise case, quoting, or internal whitespace: those
    would hide real edits. A reformatted query is a different query for the
    purpose of 'this is what produced the stored result'.
    """
    return "\n".join(line.rstrip() for line in text.replace("\r\n", "\n").split("\n")).strip()


def fetch(query_id: int, key: str) -> str:
    req = urllib.request.Request(
        f"https://api.dune.com/api/v1/query/{query_id}",
        headers={"X-Dune-API-Key": key},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["query"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="print file → query_id and exit")
    args = ap.parse_args()

    if args.list:
        for f, q in QUERIES.items():
            print(f"{q}  {f}")
        return 0

    key = os.environ.get("DUNE_API_KEY")
    if not key:
        print("DUNE_API_KEY not set. Export it, or run --list.", file=sys.stderr)
        return 2

    drifted, missing = [], []
    for fname, qid in QUERIES.items():
        path = HERE / fname
        if not path.exists():
            missing.append(fname)
            print(f"MISSING  {fname}")
            continue
        try:
            remote = fetch(qid, key)
        except urllib.error.HTTPError as e:
            print(f"ERROR    {fname}  (query {qid}): HTTP {e.code}", file=sys.stderr)
            drifted.append(fname)
            continue

        local_b, remote_b = normalise(body(path.read_text())), normalise(remote)
        if local_b == remote_b:
            print(f"ok       {fname}  (query {qid})")
        else:
            drifted.append(fname)
            print(f"DRIFTED  {fname}  (query {qid})")
            for line in difflib.unified_diff(
                remote_b.split("\n"), local_b.split("\n"),
                fromfile=f"dune:{qid}", tofile=fname, lineterm="", n=2
            ):
                print("    " + line)

    print()
    if drifted or missing:
        print(f"FAIL: {len(drifted)} drifted, {len(missing)} missing, "
              f"{len(QUERIES) - len(drifted) - len(missing)} ok")
        print("A drift is not automatically a bug in the file — Dune may have been "
              "edited since. Decide which side is authoritative before overwriting "
              "either one.")
        return 1

    print(f"OK: all {len(QUERIES)} files match Dune.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
