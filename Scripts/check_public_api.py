#!/usr/bin/env python3
"""Check the reviewed 1.0 candidate's source API against Swift symbol graphs.

This catches removed declarations, changed signatures and lost conformances.
Defaults, raw identifier values and behavioural compatibility still need review.
The candidate baseline is not an assertion that 1.0 has been released.
"""

import argparse
import json
from pathlib import Path
from urllib.parse import unquote, urlparse


MODULES = ("GMSetzer", "SetzerSyntax", "SetzerParser", "SetzerExtensions",
           "SetzerHTML", "SetzerAnalysis")


def public_api(graph_dir, root):
    result = {module: {} for module in MODULES}
    seen = set()
    for path in sorted(graph_dir.rglob("*.symbols.json")):
        owner = path.name.split(".")[0].split("@")[0]
        if owner not in result:
            continue
        graph = json.loads(path.read_text())
        if path.name == owner + ".symbols.json":
            seen.add(owner)
        conforms = {}
        for rel in graph.get("relationships", []):
            if rel["kind"] == "conformsTo":
                conforms.setdefault(rel["source"], set()).add(json.dumps(
                    {k: rel[k] for k in ("target", "swiftConstraints") if k in rel}, sort_keys=True))
        for symbol in graph["symbols"]:
            source = Path(unquote(urlparse(symbol.get("location", {}).get("uri", "")).path))
            if symbol.get("accessLevel") not in ("public", "open") or not source.is_relative_to(root / "Sources" / owner):
                continue
            key = symbol["identifier"]["precise"]
            entry = {"path": symbol["pathComponents"], "kind": symbol["kind"]["identifier"],
                     "declaration": " ".join("".join(f["spelling"] for f in symbol["declarationFragments"]).split()),
                     "conformances": sorted(conforms.get(key, []))}
            previous = result[owner].get(key)
            if previous is not None and previous != entry:
                raise ValueError(f"conflicting symbol graphs for {owner}: {entry['path']}")
            result[owner][key] = entry
    if seen != set(MODULES) or any(not symbols for symbols in result.values()):
        raise ValueError("complete nonempty symbol graphs for all six library modules are required")
    return result


def normalise_extension_contexts(modules):
    """Drop presentation-only extension blocks, retaining real declarations.

    Standalone extraction can repeat the extended type in its extension's
    graph as a `swift.extension` grouping node. Compile-time emission omits
    that node. The defining type and every member are still tracked. An
    extension block with recorded conformances is deliberately not discarded.
    """
    return {module: {key: entry for key, entry in symbols.items()
                     if entry["kind"] != "swift.extension" or entry["conformances"]}
            for module, symbols in modules.items()}


def incompatibilities(baseline, current):
    baseline = normalise_extension_contexts(baseline)
    current = normalise_extension_contexts(current)
    errors = []
    for module, symbols in baseline.items():
        for key, old in symbols.items():
            new = current.get(module, {}).get(key)
            label = module + "/" + ".".join(old["path"])
            if new is None:
                errors.append("Removed: " + label)
            elif any(old[k] != new[k] for k in ("path", "kind", "declaration")):
                errors.append("Changed: " + label)
            elif not set(old["conformances"]).issubset(new["conformances"]):
                errors.append("Lost conformance: " + label)
        enums = {tuple(s["path"]) for s in symbols.values() if s["kind"] == "swift.enum"}
        for key, new in current.get(module, {}).items():
            if key not in symbols and new["kind"] == "swift.enum.case" and tuple(new["path"][:-1]) in enums:
                errors.append("Added case to existing enum: " + module + "/" + ".".join(new["path"]))
    return errors


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--graph-dir", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, default=root / "Docs/API/1.0-candidate.json")
    parser.add_argument("--write-baseline", action="store_true",
                        help="create a new baseline; refuses to overwrite an existing file")
    args = parser.parse_args()
    current = normalise_extension_contexts(public_api(args.graph_dir, root))
    if args.write_baseline:
        args.baseline.parent.mkdir(parents=True, exist_ok=True)
        with args.baseline.open("x") as output:
            json.dump({"format": 1, "status": "1.0 candidate; owner review pending", "modules": current},
                      output, indent=2, sort_keys=True)
            output.write("\n")
    else:
        baseline = json.loads(args.baseline.read_text())
        if baseline.get("format") != 1:
            parser.error("unsupported API baseline format")
        errors = incompatibilities(baseline["modules"], current)
        if errors:
            parser.exit(1, "\n".join(errors) + "\n")
    print(f"Public API check: {sum(map(len, current.values()))} source declarations across six modules.")


if __name__ == "__main__":
    main()
