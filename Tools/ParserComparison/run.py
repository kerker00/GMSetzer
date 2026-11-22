#!/usr/bin/env python3
"""Optional same-input CommonMark comparison; owner-authorized timing only."""
import argparse
import hashlib
from html.parser import HTMLParser
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import time


class CanonicalHTML(HTMLParser):
    """Ignore structural formatting/void spelling, preserve inline/pre text."""
    VOID = {"br", "hr", "img", "input", "meta", "link", "area", "base", "col", "embed", "param", "source", "track", "wbr"}
    STRUCTURAL = {"root", "ul", "ol", "blockquote", "table", "thead", "tbody", "tr"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.events = []
        self.stack = ["root"]

    def handle_starttag(self, tag, attrs):
        self.events.append(("start", tag, tuple(sorted(attrs))))
        if tag not in self.VOID:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if tag in self.VOID:
            return
        if self.stack[-1] != tag:
            raise ValueError("unexpected generated HTML close tag: " + tag)
        self.stack.pop()
        self.events.append(("end", tag))

    def handle_data(self, data):
        if data.isspace() and self.stack[-1] in self.STRUCTURAL:
            return
        if self.events and self.events[-1][0] == "text":
            self.events[-1] = ("text", self.events[-1][1] + data)
        else:
            self.events.append(("text", data))

    def handle_comment(self, data):
        self.events.append(("comment", data))


def canonical_html(data):
    parser = CanonicalHTML()
    parser.feed(data.decode("utf-8"))
    parser.close()
    if parser.stack != ["root"]:
        raise ValueError("unclosed generated HTML")
    return parser.events


def metric(raw, expected_iterations):
    result = json.loads(raw)
    if set(result) != {"elapsed_ns", "iterations", "observed"}:
        raise ValueError("invalid adapter metrics")
    if any(type(value) is not int or value <= 0 for value in result.values()):
        raise ValueError("adapter metrics must be positive integers")
    if result["iterations"] != expected_iterations:
        raise ValueError("adapter iteration mismatch")
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift-probe", required=True, type=Path)
    parser.add_argument("--md4c-probe", required=True, type=Path)
    parser.add_argument("--pulldown-probe", required=True, type=Path)
    parser.add_argument("--external-receipt", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--run-all", action="store_true", help="Run eight rotated timing rounds after correctness checks")
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    environment = os.environ.copy()
    for name in ["LD_PRELOAD", "DYLD_INSERT_LIBRARIES"]:
        environment.pop(name, None)
    programs = {"gmsetzer": args.swift_probe.resolve(), "cmark": args.swift_probe.resolve(),
                "md4c": args.md4c_probe.resolve(), "pulldown": args.pulldown_probe.resolve()}
    root = Path(__file__).resolve().parents[2]
    sources = [root / "Package.swift", *(root / "Sources").rglob("*.swift"),
               root / "Tools/Package.swift", root / "Tools/Package.resolved",
               root / "Tools/Sources/BenchmarkCorpus/Corpus.swift",
               root / "Tools/Sources/ParserComparisonProbe/main.swift",
               *Path(__file__).parent.glob("*.py"), *Path(__file__).parent.glob("*.c"),
               Path(__file__).parent / "pulldown/Cargo.toml",
               Path(__file__).parent / "pulldown/Cargo.lock",
               Path(__file__).parent / "pulldown/src/main.rs"]
    receipt = {"schema": 1, "profile": "CommonMark (no optional extensions)",
               "scope": "AST construction/destruction versus consumed callback/offset events; HTML includes fresh output allocation. Not equivalent-work parser or C-parity evidence.",
               "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
               "load_before": os.getloadavg(), "external_build": json.loads(args.external_receipt.read_text()),
               "source_sha256": {str(p.relative_to(root)): digest(p) for p in sources},
               "binary_sha256": {name: digest(p) for name, p in programs.items()},
               "html_verification": [], "calibration": [], "cases": []}

    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def execute(command):
        result = subprocess.run(command, env=environment, capture_output=True, timeout=30, check=True)
        if result.stderr:
            raise ValueError("unexpected adapter stderr: " + result.stderr.decode())
        return result.stdout

    save()
    execute([str(args.swift_probe.resolve()), "corpus", str(out / "corpus")])
    inputs = sorted((out / "corpus").glob("*.md"), key=lambda p: p.stat().st_size)
    if len(inputs) != 3:
        raise ValueError("expected three original mixed-v1 corpora")
    for source in inputs:
        expected = None
        for name, executable in programs.items():
            command = [str(executable), name, "emit", str(source), "commonmark", "1"]
            html = execute(command)
            (out / (source.stem + "-" + name + ".html")).write_bytes(html)
            normalized = canonical_html(html)
            if expected is None:
                expected = normalized
            if normalized != expected:
                raise ValueError("HTML structure/text mismatch: " + source.name + "/" + name)
            receipt["html_verification"].append({"parser": name, "input": source.name,
                "input_bytes": source.stat().st_size, "input_sha256": digest(source),
                "html_bytes": len(html), "html_sha256": hashlib.sha256(html).hexdigest(),
                "canonical_sha256": hashlib.sha256(json.dumps(normalized).encode()).hexdigest()})
    save()
    if args.run_all:
        for source in inputs:
            for mode in ["parse", "html"]:
                configurations = []
                for name, executable in programs.items():
                    base = [str(executable), name, mode, str(source), "commonmark"]
                    trial = metric(execute(base + ["1"]), 1)
                    iterations = min(100_000, max(1, math.ceil(200_000_000 / trial["elapsed_ns"])))
                    receipt["calibration"].append({"parser": name, "input": source.name, "mode": mode,
                        "trial": trial, "iterations": iterations})
                    row = {"parser": name, "input": source.name, "bytes": source.stat().st_size,
                           "mode": mode, "command": base + [str(iterations)], "samples": []}
                    configurations.append(row)
                    receipt["cases"].append(row)
                for turn in range(8):
                    for position in range(4):
                        row = configurations[(position + turn) % 4]
                        sample = metric(execute(row["command"]), int(row["command"][-1]))
                        row["samples"].append(sample)
                        save()
                for row in configurations:
                    values = [s["elapsed_ns"] / s["iterations"] / 1_000_000 for s in row["samples"]]
                    row["milliseconds_p50"] = statistics.median(values)
                    print(source.name, mode, row["parser"], round(row["milliseconds_p50"], 3), flush=True)
    for name, path in programs.items():
        if digest(path) != receipt["binary_sha256"][name]:
            raise ValueError("binary changed during comparison: " + name)
    for name, value in receipt["source_sha256"].items():
        if digest(root / name) != value:
            raise ValueError("source changed during comparison: " + name)
    receipt.update(status="passed", load_after=os.getloadavg(),
                   finished_utc=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    save()


if __name__ == "__main__":
    main()
