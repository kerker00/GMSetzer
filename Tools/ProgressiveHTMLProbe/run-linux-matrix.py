#!/usr/bin/env python3
"""Sequential Linux M6 stage/RSS/allocation matrix. No external packages needed."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time

WORKLOADS = ("mixed", "prose", "small-blocks", "tables", "long-code", "multibyte", "extensions")
SIZES = (100_000, 1_000_000, 5_000_000)
MODES = ("parse", "full", "first", "groups")


def read_text(path):
    try:
        return Path(path).read_text().strip().strip("\0")
    except (OSError, UnicodeError):
        return None


def host_state():
    return {
        "loadavg": os.getloadavg(),
        "thermal_millidegrees_c": read_text("/sys/class/thermal/thermal_zone0/temp"),
        "scaling_governor": read_text("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"),
        "scaling_frequency_khz": read_text("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"),
    }


def execute(binary, size, workload, syntax, mode, iterations=1, allocator=None):
    env = os.environ.copy()
    env.pop("LD_PRELOAD", None)
    if allocator:
        env["LD_PRELOAD"] = str(allocator)
    command = [str(binary), str(size), str(iterations), workload, syntax, mode]
    start = time.monotonic()
    completed = subprocess.run(command, env=env, capture_output=True, text=True, timeout=240, check=True)
    record = json.loads(completed.stdout)
    assert record["allocation_interposition"] == bool(allocator)
    record["driver_wall_seconds"] = time.monotonic() - start
    # Runtime startup messages are preserved once in the receipt, not mixed into JSON.
    return record, completed.stderr.strip()


def stage_median(samples, *stages):
    return statistics.median(sum(sample[stage]["ms"] for stage in stages) for sample in samples)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--allocator", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--smoke", action="store_true", help="Only 100 KB mixed, syntax off")
    args = parser.parse_args()
    args.binary = args.binary.resolve()
    args.allocator = args.allocator.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    root = Path(__file__).resolve().parents[2]
    files = [root / "Package.swift", *sorted((root / "Sources").rglob("*.swift")),
             Path(__file__).resolve(), root / "Tools/ProgressiveHTMLProbe/Package.swift",
             root / "Tools/ProgressiveHTMLProbe/Sources/ProgressiveHTMLProbe/main.swift",
             *sorted((root / "Tools/ProgressiveHTMLProbe/Support").glob("*.c"))]
    receipt = {
        "schema": 1, "date_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "library_revision": "087e694", "library_changes_after_revision": False,
        "harness": "progressive-v2 (source hashes identify uncommitted measurement tools)",
        "os_release": read_text("/etc/os-release"), "architecture": platform.machine(),
        "kernel": platform.release(), "hardware_model": read_text("/proc/device-tree/model"),
        "meminfo": read_text("/proc/meminfo"), "logical_cpus": os.cpu_count(),
        "affinity": sorted(os.sched_getaffinity(0)), "before": host_state(),
        "swift": subprocess.check_output([str(Path.home() / ".local/opt/swift-6.4.2/usr/bin/swift"), "--version"], text=True).strip(),
        "cc": subprocess.check_output(["cc", "--version"], text=True).splitlines()[0],
        "source_sha256": {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files},
        "binary_sha256": hashlib.sha256(args.binary.read_bytes()).hexdigest(),
        "allocator_sha256": hashlib.sha256(args.allocator.read_bytes()).hexdigest(),
        "timing_iterations": 8, "timing_warmup_iterations": 1, "rss_fresh_process_repeats": 3,
        "allocation_fresh_process_repeats": 1,
        "scope": "Stage probe, not package-benchmark/C comparison. RSS is whole-process high-water memory including source generation and parsing. Allocation counts/bytes are successful requests on the synchronous calling thread, include realloc's full requested size, exclude frees, and are not live/retained memory. Instrumented timings are not used.",
    }
    (args.output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    summaries, warnings = [], set()
    cases = [(w, s, a) for w in WORKLOADS for s in SIZES for a in ("syntax-off", "syntax-on")]
    if args.smoke:
        cases = [("mixed", 100_000, "syntax-off")]
    started = time.monotonic()
    for number, (workload, size, syntax) in enumerate(cases, 1):
        case = f"{workload}-{size}-{syntax}"
        path = args.output / case
        path.mkdir()
        verified, warning = execute(args.binary, size, workload, syntax, "verify")
        warnings.add(warning)
        assert verified["samples"][0]["exact_html_equal"]
        (path / "verify.json").write_text(json.dumps(verified, indent=2) + "\n")
        timing, warning = execute(args.binary, size, workload, syntax, "timing", iterations=8)
        warnings.add(warning)
        (path / "timing.json").write_text(json.dumps(timing, indent=2) + "\n")
        memory = {}
        allocations = {}
        for mode in MODES:
            memory[mode] = []
            for repeat in range(3):
                rss, warning = execute(args.binary, size, workload, syntax, mode)
                warnings.add(warning)
                memory[mode].append(rss["process_peak_rss_kib"])
                (path / f"rss-{mode}-{repeat + 1}.json").write_text(json.dumps(rss, indent=2) + "\n")
            allocation, warning = execute(args.binary, size, workload, syntax, mode, allocator=args.allocator)
            warnings.add(warning)
            allocations[mode] = allocation["samples"][0]
            (path / f"allocations-{mode}.json").write_text(json.dumps(allocation, indent=2) + "\n")
        samples = timing["samples"]
        summary = {
            "case": case, "source_bytes": timing["source_bytes"], "syntax_details": timing["syntax_details"],
            "nodes": samples[0]["nodes"], "groups": samples[0]["groups"],
            "html_bytes": samples[0]["html_bytes"], "first_group_bytes": samples[0]["first_group_bytes"],
            "largest_group_source_bytes": samples[0]["largest_group_source_bytes"],
            "appendix_groups": samples[0]["appendix_groups"], "plan_mode": samples[0]["plan_mode"],
            "parse_ms_p50": stage_median(samples, "parse"),
            "full_ms_p50": stage_median(samples, "full"),
            "prepare_ms_p50": stage_median(samples, "prepare"),
            "first_render_ms_p50": stage_median(samples, "first"),
            "first_ready_ms_p50": stage_median(samples, "prepare", "first"),
            "all_groups_ms_p50": stage_median(samples, "prepare", "first", "remaining_groups"),
            "parse_plus_first_ms_p50": stage_median(samples, "parse", "prepare", "first"),
            "parse_plus_full_ms_p50": stage_median(samples, "parse", "full"),
            "timing_samples_ms": {label: [sum(s[stage]["ms"] for stage in stages) for s in samples] for label, stages in {
                "parse": ("parse",), "full": ("full",), "first_ready": ("prepare", "first"),
                "all_groups": ("prepare", "first", "remaining_groups")}.items()},
            "rss_kib": memory, "rss_kib_p50": {mode: statistics.median(values) for mode, values in memory.items()},
            "allocation_stage_samples": allocations,
        }
        summaries.append(summary)
        (args.output / "summary.json").write_text(json.dumps(summaries, indent=2) + "\n")
        print(f"{number}/{len(cases)} {case}: parse {summary['parse_ms_p50']:.2f} ms; full {summary['full_ms_p50']:.2f} ms; first {summary['first_ready_ms_p50']:.2f} ms; all {summary['all_groups_ms_p50']:.2f} ms; RSS full/groups {summary['rss_kib_p50']['full']}/{summary['rss_kib_p50']['groups']} KiB", flush=True)
    receipt["after"] = host_state()
    receipt["elapsed_seconds"] = time.monotonic() - started
    receipt["cases_completed"] = len(summaries)
    # Backtrace warnings contain per-process addresses: keep a stable description.
    receipt["runtime_startup_warning"] = "swift-backtrace protection unavailable; runtime disables backtracing" if any(warnings) else None
    (args.output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    main()
