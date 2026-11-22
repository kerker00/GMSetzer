#!/usr/bin/env python3
"""Bounded native scan experiment, separate from the production parser package."""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import signal
import statistics
import subprocess
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--asan", action="store_true", help="Verify only, Debug + AddressSanitizer; no timings")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    files = [root / "Sources/SetzerSyntax/ByteSearch.swift",
             *[Path(__file__).with_name(n) for n in ["Scanning.swift", "main.swift", "run.py"]]]
    runtime = [root / "Package.swift", *sorted((root / "Sources").rglob("*.swift"))]
    receipt = dict(status="running", architecture=platform.machine(), os=platform.platform(),
                   logical_cpus=os.cpu_count(), sanitizer="AddressSanitizer" if args.asan else None,
                   source_sha256={str(p.relative_to(root)): digest(p) for p in files},
                   runtime_source_sha256={str(p.relative_to(root)): digest(p) for p in runtime}, phases={})

    def save():
        (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def run(label, command, timeout=180):
        start = time.monotonic()
        with (output / (label + ".stdout")).open("wb") as stdout, (output / (label + ".stderr")).open("wb") as stderr:
            process = subprocess.Popen(command, cwd=root, stdout=stdout, stderr=stderr, start_new_session=True)
            try:
                code, timed_out = process.wait(timeout=timeout), False
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                code, timed_out = None, True
        receipt["phases"][label] = dict(command=command, exit_code=code, timed_out=timed_out,
                                       elapsed_seconds=time.monotonic() - start)
        save()
        if code != 0 or timed_out:
            raise RuntimeError(label + " failed; inspect retained logs")
        return (output / (label + ".stdout")).read_text()

    save()
    try:
        receipt["compiler"] = run("compiler", ["swiftc", "--version"])
        flags = ["-swift-version", "6", "-package-name", "GMSetzer"]
        if platform.system() == "Darwin":
            sdk = run("sdk", ["xcrun", "--show-sdk-path"]).strip()
            flags += ["-target", platform.machine() + "-apple-macosx15.0", "-sdk", sdk]
        flags += ["-module-cache-path", str(output / "module-cache")]
        if args.asan:
            flags += ["-Onone", "-g", "-sanitize=address"]
        else:
            flags += ["-O", "-whole-module-optimization"]
        binary = output / "ScanProbe"
        run("build", ["swiftc", *flags, *map(str, files[:3]), "-o", str(binary)])
        receipt["binary_sha256"] = digest(binary)
        receipt["load_before"] = os.getloadavg()
        arguments = ["--verify-only"] if args.asan else []
        report = json.loads(run("probe", [str(binary), *arguments]))
        receipt["load_after"] = os.getloadavg()
        assert report["verifiedViews"] == 15_520
        assert report["rounds"] == (0 if args.asan else 10)
        rows = report["rows"]
        assert len(rows) == (0 if args.asan else 60)
        summary = []
        if not args.asan:
            expected = {(c, s, a) for c in ["lines-80-v1", "dense-crlf-v1", "multibyte-v1", "long-line-v1"]
                        for s in [65_536, 1_048_576, 5_242_880]
                        for a in ["buffer-scalar", "span-scalar", "word8-current", "simd16", "simd32"]}
            assert {(r["corpus"], r["bytes"], r["strategy"]) for r in rows} == expected
            by_key = {(r["corpus"], r["bytes"], r["strategy"]): r for r in rows}
            for row in rows:
                values = row["samplesNanosecondsPerScan"]
                assert len(values) == len(row["checksums"]) == 10
                assert all(isinstance(v, (float, int)) and math.isfinite(v) and v > 0 for v in values)
                baseline = by_key[(row["corpus"], row["bytes"], "word8-current")]
                assert row["checksums"] == baseline["checksums"]
                assert row["iterationsPerSample"] == baseline["iterationsPerSample"]
                median = statistics.median(values)
                summary.append(dict(corpus=row["corpus"], bytes=row["bytes"], strategy=row["strategy"],
                                    median_us=median / 1000, decimal_MB_per_second=row["bytes"] * 1000 / median,
                                    time_over_current_word8=median / statistics.median(baseline["samplesNanosecondsPerScan"])))
        for name, expected_hash in {**receipt["source_sha256"], **receipt["runtime_source_sha256"]}.items():
            assert digest(root / name) == expected_hash, name
        assert digest(binary) == receipt["binary_sha256"]
        (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        receipt.update(status="passed", verified_views=report["verifiedViews"], measured_cases=len(rows),
                       source_and_binary_hashes_unchanged=True)
    except Exception as error:
        receipt.update(status="failed", error=str(error))
        raise
    finally:
        save()
    print(json.dumps({k: receipt[k] for k in ["status", "verified_views", "measured_cases"]}))


if __name__ == "__main__":
    main()
