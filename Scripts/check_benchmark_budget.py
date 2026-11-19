#!/usr/bin/env python3
"""Check local parse budgets from package-benchmark's Markdown output."""

import argparse
from dataclasses import dataclass
import json
import math
from pathlib import Path
import re
import sys


@dataclass(frozen=True)
class Timing:
    name: str
    milliseconds: float
    samples: int
    byte_count: int
    corpus: str


CASE = re.compile(
    r"^(GMSetzer|cmark-gfm \(C\)) (CommonMark|GFM) parse "
    r"(100 KB|1 MB|5 MB) \(bytes: (\d+), corpus: ([^)]+)\)$"
)
TIME = re.compile(r"^Time \(wall clock\) \(([^)]+)\)(?: \*)?$")
MILLISECONDS = {"ns": 0.000001, "μs": 0.001, "µs": 0.001, "ms": 1, "s": 1000}
ABSOLUTE = {"100 KB": 10.0, "1 MB": 60.0, "5 MB": 300.0}


def parse_results(text):
    results = {}
    current = None
    headers = set()
    for line in text.splitlines():
        if line.startswith("### "):
            name = line[4:].strip()
            if name in headers:
                raise ValueError("duplicate case: " + name)
            headers.add(name)
            current = CASE.fullmatch(name)
            continue
        if current is None or not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        metric = TIME.fullmatch(cells[0])
        if metric is None:
            continue
        if len(cells) != 9 or metric[1] not in MILLISECONDS:
            raise ValueError("unsupported timing row: " + line)
        value = float(cells[3]) * MILLISECONDS[metric[1]]
        samples = int(cells[8])
        if not math.isfinite(value) or value <= 0 or samples <= 0:
            raise ValueError("invalid timing or sample count: " + line)
        engine, profile, size, byte_count, corpus = current.groups()
        key = (engine, profile, size)
        if key in results:
            raise ValueError("ambiguous timing: " + current[0])
        results[key] = Timing(current[0], value, samples, int(byte_count), corpus)
    return results


def evaluate(results, baseline=None, regression_percent=None):
    rows = []
    failures = []
    if baseline is not None and (
        regression_percent is None or not math.isfinite(regression_percent) or regression_percent < 0
    ):
        raise ValueError("baseline comparison requires a finite non-negative regression percentage")
    for profile in ["CommonMark", "GFM"]:
        for size, absolute in ABSOLUTE.items():
            try:
                gm = results[("GMSetzer", profile, size)]
                c = results[("cmark-gfm (C)", profile, size)]
            except KeyError as error:
                raise ValueError("missing required case: " + str(error.args[0])) from error
            if gm.byte_count <= 0 or (gm.byte_count, gm.corpus) != (c.byte_count, c.corpus):
                raise ValueError("non-matching input: " + gm.name)
            limit = min(absolute, 2 * c.milliseconds)
            passed = gm.milliseconds < absolute and gm.milliseconds <= 2 * c.milliseconds
            row = dict(profile=profile, size=size, bytes=gm.byte_count, corpus=gm.corpus,
                       gm_ms=gm.milliseconds, c_ms=c.milliseconds,
                       ratio=gm.milliseconds / c.milliseconds, limit_ms=limit,
                       remaining_ms=limit - gm.milliseconds, budget_passed=passed)
            if not passed:
                failures.append("parse budget exceeded: " + gm.name)
            if baseline is not None:
                previous = baseline.get(("GMSetzer", profile, size))
                if previous is None or previous.name != gm.name:
                    raise ValueError("baseline case/input changed: " + gm.name)
                regression = (gm.milliseconds / previous.milliseconds - 1) * 100
                row["regression_percent"] = regression
                if regression > regression_percent:
                    failures.append("regression tolerance exceeded: " + gm.name)
            rows.append(row)
    return dict(cases=rows, failures=failures,
                scope="Current block parser only; passing does not prove complete inline/GFM performance.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--max-regression-percent", type=float)
    args = parser.parse_args()
    if args.baseline is None and args.max_regression_percent is not None:
        parser.error("--max-regression-percent requires --baseline")
    try:
        report = evaluate(parse_results(args.results.read_text()),
                          parse_results(args.baseline.read_text()) if args.baseline else None,
                          args.max_regression_percent)
    except (ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2))
    return 1 if report["failures"] else 0


if __name__ == "__main__":
    sys.exit(main())
