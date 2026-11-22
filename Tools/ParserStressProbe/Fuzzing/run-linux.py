#!/usr/bin/env python3
"""Run bounded coverage-guided Swift checks using an existing Linux Clang runtime.

No packages or toolchains are installed. AddressSanitizer is not enabled by
this runner; the separate Mac ASan checks retain their own scope.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--seconds", default=180, type=int)
    args = parser.parse_args()
    if sys.platform != "linux" or not 1 <= args.seconds <= 3600:
        parser.error("requires native Linux and a 1–3600 second campaign")
    root = Path(__file__).resolve().parents[3]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = Path(__file__).with_name("ParserFuzz.swift")
    files = [root / "Package.swift", *(root / "Sources").rglob("*.swift"), source, Path(__file__)]
    receipt = dict(status="running", sanitizer="coverage-guided libFuzzer; no AddressSanitizer",
                   maximum_input_bytes=4096, seed=7348327, requested_seconds=args.seconds,
                   source_sha256={str(p.relative_to(root)): digest(p) for p in files}, phases={})

    def save():
        (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def run(label, command, timeout=240):
        start = time.monotonic()
        with (output / (label + ".stdout")).open("wb") as stdout, (output / (label + ".stderr")).open("wb") as stderr:
            process = subprocess.Popen(command, cwd=root, stdout=stdout, stderr=stderr, start_new_session=True)
            try:
                code, timed_out = process.wait(timeout=timeout), False
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
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
        receipt["swift"] = run("swift-version", ["swift", "--version"])
        receipt["clang"] = run("clang-version", ["clang", "--version"])
        triple = run("clang-target", ["clang", "-dumpmachine"]).strip()
        architecture = triple.split("-")[0]
        runtimes = [Path(run("runtime-" + name, ["clang", "--print-file-name=libclang_rt." + name
                                               + "-" + architecture + ".a"]).strip())
                    for name in ["fuzzer", "ubsan_standalone"]]
        if not all(p.is_absolute() and p.is_file() for p in runtimes):
            raise RuntimeError("existing Clang fuzzer/UBSan runtimes are required")
        receipt["runtime_sha256"] = {str(p): digest(p) for p in runtimes}
        run("build", ["swift", "build", "--target", "GMSetzer", "--scratch-path", str(output / "build"),
                      "--build-system", "native", "--jobs", "2", "--disable-sandbox",
                      "-Xswiftc", "-sanitize=fuzzer"])
        binaries = list((output / "build").glob("*-unknown-linux-gnu/debug"))
        if len(binaries) != 1:
            raise RuntimeError("ambiguous native build directory")
        binary = binaries[0]
        objects = sorted(binary.glob("*.build/*.swift.o"))
        if not objects:
            raise RuntimeError("no instrumented library objects")
        symbols = run("coverage-symbols", ["nm", *map(str, objects)])
        if "__sanitizer_cov_" not in symbols:
            raise RuntimeError("library objects lack coverage instrumentation")
        harness = output / "ParserFuzz.o"
        run("harness", ["swiftc", "-Onone", "-g", "-sanitize=fuzzer", "-parse-as-library",
                        "-I", str(binary / "Modules"), "-c", str(source), "-o", str(harness)])
        executable = output / "ParserFuzz"
        # Compile instrumentation without invoking Swift's unavailable bundled
        # sanitizer linker runtimes. Link the installed system archives directly.
        run("link", ["swiftc", "-g", str(harness), *map(str, objects),
                     *[argument for p in runtimes for argument in ["-Xlinker", str(p)]],
                     "-lstdc++", "-lpthread", "-ldl", "-lrt", "-lm", "-o", str(executable)])
        receipt["binary_sha256"] = digest(executable)
        corpus, crashes = output / "corpus", output / "crashes"
        corpus.mkdir()
        crashes.mkdir()
        seeds = [b"", "text ä😀 日本語\r\n".encode(), bytes([255, 128, 192, 175, 0, 240, 159, 152, 13, 10]),
                 b"x " + b"[" * 4000, b"> " * 256 + b"body\n",
                 b"x " + b"*" * 1023 + b"a" + b"*" * 1022,
                 b"---\ntitle: test\n---\n\nText $x$ [^a].\n\n> [!tip]- title\n> body\n\n[^a]: note [^a]\n\n| a | b |\n| - | - |\n| x | y |\n\n```math\nx + y\n```\n"]
        for index, seed in enumerate(seeds):
            (corpus / ("seed-" + str(index))).write_bytes(seed)
        receipt["initial_corpus_sha256"] = {p.name: digest(p) for p in corpus.iterdir()}
        run("campaign", [str(executable), str(corpus), "-max_total_time=" + str(args.seconds),
                         "-max_len=4096", "-timeout=5", "-rss_limit_mb=2048", "-seed=7348327",
                         "-use_value_profile=1", "-print_final_stats=1", "-artifact_prefix=" + str(crashes) + "/"],
            timeout=args.seconds + 60)
        log = (output / "campaign.stderr").read_text()
        units = re.search(r"stat::number_of_executed_units:\s*(\d+)", log)
        if not units or int(units[1]) <= len(seeds) or "inline 8-bit counters" not in log:
            raise RuntimeError("campaign lacks executed-unit/coverage evidence")
        if any(crashes.iterdir()):
            raise RuntimeError("campaign produced a failure artifact")
        for name, expected in receipt["source_sha256"].items():
            if digest(root / name) != expected:
                raise RuntimeError("source changed: " + name)
        receipt.update(status="passed", executed_units=int(units[1]), source_hashes_unchanged=True,
                       final_corpus_files=sum(1 for _ in corpus.iterdir()))
    except Exception as error:
        receipt.update(status="failed", error=str(error))
        raise
    finally:
        save()
    print(json.dumps({key: receipt[key] for key in ["status", "executed_units", "maximum_input_bytes"]}))


if __name__ == "__main__":
    main()
