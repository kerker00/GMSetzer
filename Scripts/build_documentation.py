#!/usr/bin/env python3
"""Build all six DocC archives with the installed Swift/DocC tools.

No DocC plugin or third-party package dependency is added to the library.
Swift Package Index injects its own documentation plugin when hosting these
same catalogs. All generated files stay under the selected output directory.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlparse


MODULES = ("SetzerSyntax", "SetzerParser", "SetzerExtensions", "SetzerHTML",
           "SetzerAnalysis", "GMSetzer")


def emit_library_graphs(root, output, jobs, run=subprocess.run):
    """Emit fresh library graphs during compilation, without test discovery."""
    graph_dir = output / "symbolgraph"
    with tempfile.TemporaryDirectory(prefix=".symbolgraph-", dir=output) as temporary:
        fresh = Path(temporary)
        command = ["swift", "build", "--package-path", str(root), "--disable-sandbox",
                   "--target", "GMSetzer", "--scratch-path", str(output / "build"),
                   "--cache-path", str(output / "cache"),
                   "--config-path", str(output / "config"),
                   "--security-path", str(output / "security"), "--jobs", str(jobs),
                   "-Xswiftc", "-emit-symbol-graph", "-Xswiftc", "-emit-symbol-graph-dir",
                   "-Xswiftc", str(fresh), "-Xswiftc", "-symbol-graph-skip-synthesized-members"]
        run(command, check=True)
        for module in MODULES:
            path = fresh / f"{module}.symbols.json"
            graph = json.loads(path.read_text())
            if graph.get("module", {}).get("name") != module or not isinstance(graph.get("symbols"), list):
                raise ValueError(f"invalid fresh library graph for {module}")
        if graph_dir.exists():
            shutil.rmtree(graph_dir)
        shutil.copytree(fresh, graph_dir)
    return graph_dir


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path(".build/documentation"))
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    root = Path(__file__).resolve().parents[1]
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    docc = shutil.which("docc")
    if not docc and sys.platform == "darwin":
        docc = subprocess.check_output(["xcrun", "--find", "docc"], text=True).strip()
    if not docc:
        parser.error("DocC must be installed with the selected Swift toolchain")
    graph_dir = emit_library_graphs(root, output, args.jobs)
    summary = {}
    for module in MODULES:
        # A fresh directory prevents a removed symbol graph surviving a rerun.
        graphs = output / "graphs" / module
        if graphs.exists():
            shutil.rmtree(graphs)
        graphs.mkdir(parents=True)
        symbols = []
        for graph in sorted(graph_dir.glob(f"{module}*.symbols.json")):
            if graph.name != f"{module}.symbols.json" and not graph.name.startswith(module + "@"):
                continue
            shutil.copy2(graph, graphs / graph.name)
            symbols.extend(json.loads(graph.read_text())["symbols"])
        if not (graphs / f"{module}.symbols.json").exists():
            raise RuntimeError(f"missing symbol graph for {module}")
        archive = output / f"{module}.doccarchive"
        subprocess.run([docc, "convert", str(root / "Sources" / module / f"{module}.docc"),
                        "--additional-symbol-graph-dir", str(graphs),
                        "--output-path", str(archive), "--warnings-as-errors",
                        "--fallback-bundle-identifier", f"net.grafixmafia.{module}",
                        "--fallback-default-module-kind", "Library"], check=True)
        # Report comment coverage without mistaking a generated reference page
        # for a completed per-symbol documentation review.
        source_dir = root / "Sources" / module
        declared = [s for s in symbols if s.get("accessLevel") in ("public", "open")
                    and Path(unquote(urlparse(s.get("location", {}).get("uri", "")).path)).is_relative_to(source_dir)]
        missing = [s for s in declared if not s.get("docComment", {}).get("lines")]
        summary[module] = {"public_symbols": len(declared),
                           "without_source_comment": len(missing),
                           "undocumented": [s["pathComponents"] for s in missing]}
    (output / "coverage.json").write_text(json.dumps(summary, indent=2) + "\n")
    print("Built six DocC archives with warnings treated as errors.")
    for module, counts in summary.items():
        print(f"{module}: {counts['public_symbols']} public symbols, "
              f"{counts['without_source_comment']} without source comments")


if __name__ == "__main__":
    main()
