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


def source_files(root, include_measurement_tools=False):
    paths = [root / "Package.swift", *(root / "Sources").rglob("*.swift")]
    if include_measurement_tools:
        probe = root / "Tools/ProgressiveHTMLProbe"
        paths.extend([probe / "Package.swift", *probe.glob("*.py"),
                      *(probe / "Sources").rglob("*.swift"), *(probe / "Support").glob("*.c")])
    return {str(path.relative_to(root)) for path in paths}


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
        if type(row["source_bytes"]) is not int or not size <= row["source_bytes"] < size + 1024:
            raise ValueError(f"unexpected input size: {name}")
        if row["plan_mode"] != "structural":
            raise ValueError(f"unexpected whole-document fallback: {name}")
        for key in ("groups", "nodes", "html_bytes", "first_group_bytes", "largest_group_source_bytes"):
            if type(row[key]) is not int or row[key] <= 0:
                raise ValueError(f"invalid structural metadata: {name}/{key}")
        if type(row["appendix_groups"]) is not int or row["appendix_groups"] != (1 if workload == "extensions" else 0):
            raise ValueError(f"unexpected appendix count: {name}")
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
        if workload == "long-code":
            latency_limit = None
        elif size == 100_000:
            latency_limit = 0.75
        elif workload == "extensions":
            latency_limit = 0.50
        else:
            latency_limit = 0.25
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


def load_evidence(directory, source_root=None, include_measurement_tools=False):
    """Verify archived evidence without extracting files or executing the probe."""
    hashes = json.loads((directory / "sha256.json").read_text())
    for name in ("raw-results.tar.gz", "receipt.json", "summary.csv", "summary.json"):
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != hashes[name]:
            raise ValueError(f"archived artifact hash mismatch: {name}")
    receipt = json.loads((directory / "receipt.json").read_text())
    rows = json.loads((directory / "summary.json").read_text())
    if not isinstance(receipt, dict) or not isinstance(receipt.get("source_sha256"), dict):
        raise ValueError("invalid source measurement receipt")
    if type(receipt.get("schema")) is not int or receipt["schema"] not in (1, 2):
        raise ValueError("unsupported measurement receipt schema")
    # Validate shape, case identity and measurements before opening raw members.
    evaluate(rows)
    if receipt["cases_completed"] != 42 or receipt["timing_iterations"] != 8 or receipt["rss_fresh_process_repeats"] != 3:
        raise ValueError("incomplete measurement receipt")
    if source_root is not None:
        recorded = {name: digest for name, digest in receipt["source_sha256"].items()
                    if name == "Package.swift" or name.startswith("Sources/")
                    or (include_measurement_tools and name.startswith("Tools/"))}
        if set(recorded) != source_files(source_root, include_measurement_tools):
            raise ValueError("measured source file inventory changed")
        for name, expected in recorded.items():
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
            mode = filename.split("-")[1] if filename.startswith("rss-") else filename
            expected.update(mode=mode, iterations=8 if mode == "timing" else 1, allocation_interposition=False)
            if not isinstance(value, dict) or any(type(value[key]) is not type(setting) or value[key] != setting
                                                  for key, setting in expected.items()):
                raise ValueError(f"raw record configuration changed: {case}/{filename}")
            if not isinstance(value["samples"], list) or len(value["samples"]) != expected["iterations"]:
                raise ValueError(f"invalid raw sample count: {case}/{filename}")
            if not all(isinstance(sample, dict) for sample in value["samples"]):
                raise ValueError(f"invalid raw samples: {case}/{filename}")
            return value

        for row in rows:
            name = row["case"]
            verified = record(row, "verify")
            if verified["samples"][0]["exact_html_equal"] is not True:
                raise ValueError(f"HTML equality failed: {name}")
            for key in ("nodes", "groups", "html_bytes"):
                if verified["samples"][0][key] != row[key]:
                    raise ValueError(f"verification structure changed: {name}/{key}")
            timing = record(row, "timing")
            samples = timing["samples"]
            if [sample["order"] for sample in samples] != ["full-first", "groups-first"] * 4:
                raise ValueError(f"timing order changed: {name}")
            for sample in samples:
                for key in ("nodes", "groups", "html_bytes", "first_group_bytes", "largest_group_source_bytes", "appendix_groups", "plan_mode"):
                    if type(sample[key]) is not type(row[key]) or sample[key] != row[key]:
                        raise ValueError(f"raw structure/summary mismatch: {name}/{key}")
                if sample["grouped_html_bytes"] != row["html_bytes"]:
                    raise ValueError(f"grouped output size changed: {name}")
            for label, stages in {"parse": ("parse",), "full": ("full",), "first_ready": ("prepare", "first"),
                                  "all_groups": ("prepare", "first", "remaining_groups")}.items():
                raw = [sum(positive(sample[stage]["ms"]) for stage in stages) for sample in samples]
                summary = row["timing_samples_ms"][label]
                if len(raw) != len(summary) or any(not math.isclose(a, b, rel_tol=1e-12) for a, b in zip(raw, summary)):
                    raise ValueError(f"raw timing/summary mismatch: {name}/{label}")
            for mode in MODES:
                memory = [record(row, f"rss-{mode}-{repeat}") for repeat in (1, 2, 3)]
                if [sample["process_peak_rss_kib"] for sample in memory] != row["rss_kib"][mode]:
                    raise ValueError(f"raw RSS/summary mismatch: {name}/{mode}")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path, help="Archived matrix directory with receipt, hashes, summary and raw results")
    parser.add_argument("--source-root", type=Path, help="Require the measured runtime manifest, complete source inventory and hashes to match")
    parser.add_argument("--include-measurement-tools", action="store_true", help="Also require the archived measurement harness to match --source-root")
    args = parser.parse_args()
    if args.include_measurement_tools and args.source_root is None:
        parser.error("--include-measurement-tools requires --source-root")
    try:
        report = evaluate(load_evidence(args.results, args.source_root, args.include_measurement_tools))
        report["source_verification"] = "not requested"
        if args.source_root is not None:
            report["source_verification"] = "runtime and measurement tools" if args.include_measurement_tools else "runtime"
    except (OSError, ValueError, KeyError, TypeError, tarfile.TarError) as error:
        print(str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2))
    return 1 if report["failures"] else 0


if __name__ == "__main__":
    sys.exit(main())
