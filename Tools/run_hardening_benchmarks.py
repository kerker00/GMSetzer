#!/usr/bin/env python3
"""List, smoke-test or explicitly run the isolated M7 hardening matrix."""

import argparse
from decimal import Decimal, InvalidOperation
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import time


TARGET = "HardeningBenchmarks"
EXPECTED_CASES = 69
SMOKE_PREFIXES = (
    "GMSetzer m5-composed-v1 parse syntax-off 16 KiB (",
    "GMSetzer m5-composed-v1 parse-render syntax-on 16 KiB (",
    "GMSetzer footnotes-repeated-v1 parse-render syntax-off 16 KiB (",
    "GMSetzer open-brackets-v1 parse syntax-off 16 KiB (",
    "cmark-gfm (C) open-brackets-v1 parse 16 KiB (",
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_filter(name):
    # The pinned tool filters baseName, but lists/exports name with tags.
    # Swift Regex consumes the complete base name; escape metacharacters only.
    base_name = name.split(" (bytes: ", 1)[0]
    return re.sub(r"([\\.^$*+?{}\[\]|()])", r"\\\1", base_name)


def execute(command, stdout, stderr, timeout):
    """The tool and its posix_spawn children inherit this private process group."""
    environment = os.environ.copy()
    for name in ("LD_PRELOAD", "DYLD_INSERT_LIBRARIES"):
        environment.pop(name, None)
    with stdout.open("wb") as out, stderr.open("wb") as err:
        process = subprocess.Popen(command, stdout=out, stderr=err, env=environment,
                                   start_new_session=True)
        try:
            return process.wait(timeout=timeout), False
        except subprocess.TimeoutExpired:
            # Kill only the group created for this command, including an active
            # benchmark child; unrelated owner processes are never enumerated.
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
            finally:
                # The parent may exit before a child finishes handling SIGTERM.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
            return process.returncode, True


def case_names(text):
    names = [line.strip() for line in text.splitlines()
             if line.startswith(("GMSetzer ", "cmark-gfm (C) ")) and " (bytes: " in line]
    if len(names) != EXPECTED_CASES or len(set(names)) != len(names):
        raise ValueError("expected 69 unique hardening cases, got " + str(len(names)))
    return names


def parse_result(text, expected):
    headers = re.findall(r"^### (.+)$", text, re.MULTILINE)
    if headers != [expected]:
        raise ValueError("missing, duplicate or unexpected case in benchmark export")
    metrics = {}
    for line in text.split("### " + expected + "\n", 1)[1].splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if not cells[0].startswith(("Time (wall clock)", "Malloc (total)", "Malloc (bytes total)")):
            continue
        if len(cells) != 9 or cells[0] in metrics:
            raise ValueError("invalid or duplicate metric row")
        try:
            value, samples = Decimal(cells[3]), int(cells[8])
        except (InvalidOperation, ValueError) as error:
            raise ValueError("invalid metric value/sample count") from error
        if not value.is_finite() or value <= 0 or samples <= 0:
            raise ValueError("timing/allocation metrics must be positive and supported")
        metrics[cells[0]] = {"p50_display": cells[3], "samples": samples}
    times = [(name, value) for name, value in metrics.items() if name.startswith("Time")]
    counts = [name for name in metrics if name.startswith("Malloc (total)")]
    volumes = [name for name in metrics if name.startswith("Malloc (bytes total)")]
    if (len(metrics) != 3 or len(times) != 1 or len(counts) != 1 or len(volumes) != 1
            or "(μs)" not in times[0][0]):
        raise ValueError("expected wall-clock microseconds and both malloc metrics")
    return {"wall_ms_p50": str(Decimal(times[0][1]["p50_display"]) / 1_000),
            "metrics": metrics}


def measurement_files(root):
    return sorted([root / "Package.swift", *(root / "Sources").rglob("*.swift"),
                   root / "Tools/Package.swift", root / "Tools/Package.resolved",
                   *(root / "Tools/Sources").rglob("*.swift"),
                   root / "Tools/Benchmarks/HardeningBenchmarks/HardeningBenchmarks.swift",
                   root / "Tools/run_hardening_benchmarks.py"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool", required=True, type=Path, help="Already built Release BenchmarkTool")
    parser.add_argument("--binary", required=True, type=Path, help="Already built Release HardeningBenchmarks")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--swift", default="swift", help="Compiler used for these binaries")
    parser.add_argument("--timeout-seconds", type=float, default=30)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list", action="store_true", help="Enumerate only; no benchmark samples")
    mode.add_argument("--smoke", action="store_true", help="Five explicitly selected 16 KiB cases")
    mode.add_argument("--run-all", action="store_true", help="Full 69-case series; obtain owner confirmation first")
    args = parser.parse_args()
    if not math.isfinite(args.timeout_seconds) or args.timeout_seconds <= 0:
        parser.error("timeout must be finite and positive")
    args.tool, args.binary = args.tool.resolve(), args.binary.resolve()
    if not args.tool.is_file() or not args.binary.is_file():
        parser.error("build both Release executables before using this driver")
    args.output.mkdir(parents=True, exist_ok=False)
    root = Path(__file__).resolve().parents[1]
    files = measurement_files(root)
    receipt = {
        "schema": 1,
        "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "git_revision": subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
        "working_tree_status": subprocess.check_output(
            ["git", "-C", str(root), "status", "--short"], text=True).splitlines(),
        "mode": "list" if args.list else "smoke" if args.smoke else "full",
        "target": TARGET, "architecture": platform.machine(), "os": platform.platform(),
        "logical_cpus": os.cpu_count(), "load_before": os.getloadavg(),
        "compiler": subprocess.check_output([args.swift, "--version"], text=True).strip(),
        "source_sha256": {str(p.relative_to(root)): digest(p) for p in files},
        "binary_sha256": {"tool": digest(args.tool), "benchmark": digest(args.binary)},
        "allocator_sha256": {p.name: digest(p) for p in sorted(args.binary.parent.iterdir())
                             if p.suffix in (".dylib", ".so")},
        "timeout_seconds_per_case": args.timeout_seconds, "max_sampling_seconds_per_case": 5,
        "cases": [], "status": "listing",
        "scope": "Fresh process group per case, direct existing Release tool; no SwiftPM/build parent. "
                 "A timeout stops the series and retains logs; it is not a pass or a timing sample. "
                 "Malloc values are gross requests/volume, not live heap or peak RSS. "
                 "C controls are informational; quote depth policies differ and M5 has no matching C profile.",
    }
    receipt_path = args.output / "receipt.json"

    def save():
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")

    save()
    common = ["--baseline-storage-path", str(args.output), "--format", "markdown",
              "--grouping", "benchmark", "--time-units", "microseconds", "--no-progress",
              "--targets", TARGET, "--benchmark-executable-paths", str(args.binary)]
    try:
        code, timed_out = execute([str(args.tool), "--command", "list", *common],
                                 args.output / "list.stdout", args.output / "list.stderr",
                                 args.timeout_seconds)
        if code or timed_out:
            raise ValueError("case listing failed or timed out")
        names = case_names((args.output / "list.stdout").read_text())
        (args.output / "cases.txt").write_text("\n".join(names) + "\n")
        receipt["cases_listed"] = len(names)
        selected = [] if args.list else names
        if args.smoke:
            selected = [name for prefix in SMOKE_PREFIXES for name in names if name.startswith(prefix)]
            if len(selected) != len(SMOKE_PREFIXES) or len(set(selected)) != len(selected):
                raise ValueError("smoke selection does not match all five expected cases")
        for number, name in enumerate(selected, 1):
            receipt["status"] = "running"
            case = {"name": name, "status": "running", "ordinal": number}
            receipt["cases"].append(case)
            save()
            stdout, stderr = args.output / f"case-{number:03d}.md", args.output / f"case-{number:03d}.stderr"
            code, timed_out = execute([str(args.tool), "--command", "run", *common,
                                       "--filter", exact_filter(name)], stdout, stderr, args.timeout_seconds)
            case.update(exit_code=code, timed_out=timed_out,
                        stdout_sha256=digest(stdout), stderr_sha256=digest(stderr))
            if timed_out or code:
                case["status"] = "timeout" if timed_out else "process-failed"
                raise ValueError("case did not complete: " + name)
            try:
                result = parse_result(stdout.read_text(), name)
            except ValueError as error:
                case.update(status="invalid-output", error=str(error))
                raise
            case.update(result, status="complete")
            print(f"{number}/{len(selected)} {name}: {case['wall_ms_p50']} ms", flush=True)
        for name, expected in receipt["source_sha256"].items():
            if digest(root / name) != expected:
                raise ValueError("measurement source changed during execution: " + name)
        if digest(args.tool) != receipt["binary_sha256"]["tool"] or digest(args.binary) != receipt["binary_sha256"]["benchmark"]:
            raise ValueError("measurement executable changed during execution")
        receipt["status"] = "listed" if args.list else "complete"
        receipt["cases_completed"] = len(selected)
        receipt["source_hashes_unchanged"] = True
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        receipt.update(status="failed", error=str(error))
        return 1
    finally:
        receipt["finished_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        receipt["load_after"] = os.getloadavg()
        save()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
