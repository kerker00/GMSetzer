#!/usr/bin/env python3
"""Check the reviewed 1.0 candidate's source API against Swift symbol graphs.

This catches removed declarations, changed signatures and lost conformances.
Defaults, raw identifier values and behavioural compatibility still need review.
The candidate baseline is not an assertion that 1.0 has been released.
"""

import argparse
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlparse


MODULES = ("GMSetzer", "SetzerSyntax", "SetzerParser", "SetzerExtensions",
           "SetzerHTML", "SetzerAnalysis")


def declaration_source(lines, start):
    """Read a declaration header, excluding its body and any following member."""
    header = []
    parentheses = brackets = 0
    quoted = escaped = False
    for line in lines[start:start + 100]:
        for character in line:
            if quoted:
                header.append(character)
                if escaped:
                    escaped = False
                elif character == "\\":
                    escaped = True
                elif character == '"':
                    quoted = False
                continue
            if character == '"':
                quoted = True
            elif character == "{" and parentheses == brackets == 0:
                return " ".join("".join(header).split())
            elif character == "(":
                parentheses += 1
            elif character == ")":
                parentheses -= 1
            elif character == "[":
                brackets += 1
            elif character == "]":
                brackets -= 1
            header.append(character)
        if parentheses == brackets == 0:
            return " ".join("".join(header).split())
        header.append("\n")
    return ""


def declaration_tokens(text):
    # Keep quoted literals, annotation positions, punctuation and all type names.
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|`[^`]+`|[A-Za-z_][A-Za-z_0-9]*|\S', text)
    if tokens[:1] == ["public"]:
        tokens = tokens[1:]
    return tokens


def same_declaration(old, new):
    if old["declaration"] == new["declaration"]:
        return True
    # Swift 6.2 symbol graphs omit @Sendable on some closure types. Accept
    # only that display omission, backed by the *complete* actual source header.
    expected = old["declaration"]
    if "@Sendable" not in expected or "source_declaration" not in new:
        return False
    without_sendable = " ".join(re.sub(r"@Sendable\s*", "", expected).split())
    return (without_sendable == new["declaration"]
            and declaration_tokens(expected) == declaration_tokens(new["source_declaration"]))


def public_api(graph_dir, root):
    result = {module: {} for module in MODULES}
    seen = set()
    source_lines = {}
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
            if "->" in entry["declaration"]:
                if source not in source_lines:
                    source_lines[source] = source.read_text().splitlines()
                line = symbol["location"].get("position", {}).get("line")
                if isinstance(line, int) and line >= 0:
                    entry["source_declaration"] = declaration_source(source_lines[source], line)
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
            elif old["path"] != new["path"] or old["kind"] != new["kind"] or not same_declaration(old, new):
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
            details = []
            for module, symbols in normalise_extension_contexts(baseline["modules"]).items():
                for key, old in symbols.items():
                    new = current.get(module, {}).get(key)
                    if new and (old["path"] != new["path"] or old["kind"] != new["kind"] or not same_declaration(old, new)):
                        label = module + "/" + ".".join(old["path"])
                        details.append(f"{label}\n  baseline: {old['declaration']}\n  current:  {new['declaration']}")
            parser.exit(1, "\n".join(errors + details) + "\n")
    print(f"Public API check: {sum(map(len, current.values()))} source declarations across six modules.")


if __name__ == "__main__":
    main()
