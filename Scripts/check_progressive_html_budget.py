#!/usr/bin/env python3
"""Evaluate the complete M6 progressive-v2 matrix against post-baseline targets.

This is a same-host stage/RSS check, not a C comparison, a controlled
statistical regression test, or a first-visible-output measurement.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import sys
import tarfile


WORKLOADS = ("mixed", "prose", "small-blocks", "tables", "long-code", "multibyte", "extensions")
SIZES = (100_000, 1_000_000, 5_000_000)
MODES = ("parse", "full", "first", "groups")
EXPECTED_CASES = {f"{w}-{s}-syntax-{a}" for w in WORKLOADS for s in SIZES for a in ("off", "on")}


def positive(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
        raise ValueError("expected a positive finite measurement")
    return value


def median(values, count):
    if not isinstance(values, list) or len(values) != count:
        raise ValueError(f"expected exactly {count} measurement samples")
    return statistics.median(positive(value) for value in values)


def evaluate(rows):
    """No faster case can compensate for another case exceeding its target."""
    if not isinstance(rows, list) or len(rows) != len(EXPECTED_CASES):
        raise ValueError("expected the complete 42-case matrix")
    if {row["case"] for row in rows} != EXPECTED_CASES:
        raise ValueError("missing, duplicate or unexpected matrix case")
    results, failures = [], []
    for row in rows:
        name = row["case"]
        # Workload names may themselves contain '-'.
        workload, nominal, _, annotation = name.rsplit("-", 3)
        size = int(nominal)
        if not isinstance(row["syntax_details"], bool) or row["syntax_details"] != (annotation == "on"):
            raise ValueError(f"syntax configuration changed: {name}")
        if not size <= positive(row["source_bytes"]) < size + 1024:
            raise ValueError(f"unexpected input size: {name}")
        if row["plan_mode"] != "structural":
            raise ValueError(f"unexpected whole-document fallback: {name}")
        samples = row["timing_samples_ms"]
        full = median(samples["full"], 8)
        first = median(samples["first_ready"], 8)
        complete = median(samples["all_groups"], 8)
        for key, measured in [("full_ms_p50", full), ("first_ready_ms_p50", first), ("all_groups_ms_p50", complete)]:
            if not math.isclose(positive(row[key]), measured, rel_tol=1e-9):
                raise ValueError(f"summary/sample mismatch: {name}/{key}")
        rss = {mode: median(row["rss_kib"][mode], 3) for mode in MODES}
        for mode in MODES:
            if positive(row["rss_kib_p50"][mode]) != rss[mode]:
                raise ValueError(f"RSS summary/sample mismatch: {name}/{mode}")
        latency_limit = None if workload == "long-code" else (0.75 if size == 100_000 else 0.50 if workload == "extensions" else 0.25)
        if workload == "long-code" and row["groups"] != 1:
            raise ValueError(f"indivisible code-block workload changed: {name}")
        if latency_limit is not None and row["groups"] < 2:
            raise ValueError(f"independent-block workload has no progressive output: {name}")
        checks = {
            "first_output": latency_limit is None or first <= latency_limit * full,
            "completion": complete <= 1.10 * full,
            "peak_rss": max(rss["first"], rss["groups"]) <= max(1.10 * rss["full"], rss["full"] + 8192),
        }
        failures.extend(f"{name}: {check}" for check, passed in checks.items() if not passed)
        results.append(dict(case=name, first_over_full=first / full, first_limit=latency_limit,
                            complete_over_full=complete / full, checks=checks))
    return dict(cases=results, failures=failures,
                scope="M6 post-baseline stage/RSS targets only; parsing precedes output; no UI latency or memory-reduction claim.")


def load_evidence(directory, source_root=None):
    """Verify archived evidence without extracting files or executing the probe."""
    hashes = json.loads((directory / "sha256.json").read_text())
    for name in ("raw-results.tar.gz", "receipt.json", "summary.csv", "summary.json"):
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != hashes[name]:
            raise ValueError(f"archived artifact hash mismatch: {name}")
    receipt = json.loads((directory / "receipt.json").read_text())
    rows = json.loads((directory / "summary.json").read_text())
    if receipt["cases_completed"] != 42 or receipt["timing_iterations"] != 8 or receipt["rss_fresh_process_repeats"] != 3:
        raise ValueError("incomplete measurement receipt")
    if source_root is not None:
        for name, expected in receipt["source_sha256"].items():
            path = (source_root / name).resolve()
            if not path.is_relative_to(source_root.resolve()):
                raise ValueError("source path outside checkout")
            if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise ValueError(f"measured source changed: {name}")
    with tarfile.open(directory / "raw-results.tar.gz") as archive:
        def record(row, filename):
            case = row["case"]
            stream = archive.extractfile(f"results/{case}/{filename}.json")
            if stream is None:
                raise ValueError(f"missing raw record: {case}/{filename}")
            value = json.load(stream)
            workload, nominal, _, annotation = case.rsplit("-", 3)
            expected = dict(corpus=f"progressive-{workload}-v2", requested_source_bytes=int(nominal),
                            source_bytes=row["source_bytes"], syntax_details=annotation == "on",
                            source_ranges=True, source_anchor_prefix="block-", group_source_budget=32768,
                            profile="commonmark" if workload == "prose" else "gfm")
            if any(value[key] != setting for key, setting in expected.items()):
                raise ValueError(f"raw record configuration changed: {case}/{filename}")
            return value

        for row in rows:
            name = row["case"]
            verified = record(row, "verify")
            if verified["samples"][0]["exact_html_equal"] is not True:
                raise ValueError(f"HTML equality failed: {name}")
            if verified["source_bytes"] != row["source_bytes"] or verified["syntax_details"] != row["syntax_details"]:
                raise ValueError(f"verification configuration changed: {name}")
            timing = record(row, "timing")
            samples = timing["samples"]
            if timing["allocation_interposition"] is not False or len(samples) != 8:
                raise ValueError(f"invalid timing process: {name}")
            if [sample["order"] for sample in samples] != ["full-first", "groups-first"] * 4:
                raise ValueError(f"timing order changed: {name}")
            for label, stages in {"parse": ("parse",), "full": ("full",), "first_ready": ("prepare", "first"),
                                  "all_groups": ("prepare", "first", "remaining_groups")}.items():
                raw = [sum(sample[stage]["ms"] for stage in stages) for sample in samples]
                summary = row["timing_samples_ms"][label]
                if len(raw) != len(summary) or any(not math.isclose(a, b, rel_tol=1e-12) for a, b in zip(raw, summary)):
                    raise ValueError(f"raw timing/summary mismatch: {name}/{label}")
            for mode in MODES:
                memory = [record(row, f"rss-{mode}-{repeat}") for repeat in (1, 2, 3)]
                if any(sample["allocation_interposition"] is not False for sample in memory):
                    raise ValueError(f"instrumented RSS process: {name}/{mode}")
                if [sample["process_peak_rss_kib"] for sample in memory] != row["rss_kib"][mode]:
                    raise ValueError(f"raw RSS/summary mismatch: {name}/{mode}")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path, help="Archived matrix directory with receipt, hashes, summary and raw results")
    parser.add_argument("--source-root", type=Path, help="Also require all measured source/tool hashes to match this checkout")
    args = parser.parse_args()
    try:
        report = evaluate(load_evidence(args.results, args.source_root))
    except (OSError, ValueError, KeyError, TypeError, tarfile.TarError) as error:
        print(str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2))
    return 1 if report["failures"] else 0


if __name__ == "__main__":
    sys.exit(main())
