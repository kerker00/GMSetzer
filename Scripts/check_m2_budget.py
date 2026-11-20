#!/usr/bin/env python3
"""Check M2 total-parse growth against M1's frozen, source-positioned baseline."""

import argparse
import hashlib
import importlib.util
import json
import math
import re
from pathlib import Path
import sys

# -I deliberately excludes the script directory from sys.path. Load this exact
# adjacent, tracked module instead of widening import search paths.
_spec = importlib.util.spec_from_file_location("_gmsetzer_benchmark_budget", Path(__file__).with_name("check_benchmark_budget.py"))
if _spec is None or _spec.loader is None:
    raise RuntimeError("cannot load adjacent benchmark-budget checker")
_gate = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = _gate
_spec.loader.exec_module(_gate)
ABSOLUTE, parse_results = _gate.ABSOLUTE, _gate.parse_results


VARIANTS = {"core": None, "selected-registry": "selected registry", "selected-inline": "selected inline"}


def variant_results(text, variant):
    """Use the same frozen core baseline for all selected-rule total costs.

    Selected cases must exist at every size; absence must not silently fall
    back to the cheaper core measurement. C controls remain from the same run.
    """
    selected = VARIANTS[variant]
    if selected is not None:
        text = re.sub(r"(?m)^### GMSetzer CommonMark parse ", "### Unselected GMSetzer CommonMark parse ", text)
        text = re.sub(r"(?m)^### GMSetzer " + re.escape(selected) + r" parse ", "### GMSetzer CommonMark parse ", text)
    return parse_results(text)


def evaluate(results, baseline, allowances):
    if set(allowances) != set(ABSOLUTE):
        raise ValueError("allowances must cover exactly 100 KB, 1 MB and 5 MB")
    rows, failures = [], []
    for size, absolute in ABSOLUTE.items():
        allowance = allowances[size]
        if isinstance(allowance, bool) or not isinstance(allowance, (int, float)) or not math.isfinite(allowance) or allowance < 0:
            raise ValueError("invalid allowance: " + size)
        try:
            key = ("GMSetzer", "CommonMark", size)
            control = ("cmark-gfm (C)", "CommonMark", size)
            gm, previous, c, previous_c = results[key], baseline[key], results[control], baseline[control]
        except KeyError as error:
            raise ValueError("missing required case: " + str(error.args[0])) from error
        identity = (gm.byte_count, gm.corpus)
        if gm.byte_count <= 0 or any((item.byte_count, item.corpus) != identity for item in [previous, c, previous_c]):
            raise ValueError("non-matching input: " + size)
        # A changed control invalidates the comparison rather than silently
        # crediting an easier run or a different machine to inline work.
        drift = (c.milliseconds / previous_c.milliseconds - 1) * 100
        limit = min(absolute, 2 * c.milliseconds)
        delta = gm.milliseconds - previous.milliseconds
        passed = delta <= allowance and gm.milliseconds < absolute and gm.milliseconds <= 2 * c.milliseconds and abs(drift) <= 10
        if not passed:
            failures.append("M2 allowance, total ceiling or control stability failed: " + size)
        rows.append(dict(size=size, bytes=gm.byte_count, corpus=gm.corpus, block_ms=previous.milliseconds,
            current_ms=gm.milliseconds, additional_ms=delta, allowance_ms=allowance,
            total_ceiling_ms=limit, c_control_drift_percent=drift, passed=passed))
    return dict(cases=rows, failures=failures,
        scope="CommonMark, annotations off; total parse delta includes all new work, not isolated inline attribution. GFM remains a later acceptance gate.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path)
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--variant", choices=VARIANTS, default="core",
                        help="Include selected block/inline rule cost in the unchanged frozen M2 allowance")
    parser.add_argument("--allowance", required=True, type=Path)
    args = parser.parse_args()
    try:
        settings = json.loads(args.allowance.read_text())
        frozen = args.baseline.read_bytes()
        if hashlib.sha256(frozen).hexdigest() != settings["baseline_sha256"]:
            raise ValueError("frozen M1 baseline hash changed")
        report = evaluate(variant_results(args.results.read_text(), args.variant), parse_results(frozen.decode()), settings["additional_parse_ms"])
        report["variant"] = args.variant
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2))
    return 1 if report["failures"] else 0


if __name__ == "__main__":
    sys.exit(main())
