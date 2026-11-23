#!/usr/bin/env python3
"""Require a SemVer tag, matching runtime identity and final versioned notes."""

import argparse
from pathlib import Path
import re


def validate_release(root, tag):
    if not re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag):
        raise ValueError("expected vMAJOR.MINOR.PATCH without leading zeroes")
    version = tag[1:]
    source = (root / "Sources/SetzerSyntax/LibraryIdentity.swift").read_text()
    identities = re.findall(r'^\s*public static let current = "([^"\n]+)"\s*$', source, re.MULTILINE)
    if identities != [version]:
        raise ValueError(f"runtime identity must be exactly {version}, found {identities}")
    notes = root / "Docs/Releases" / (version + ".md")
    lines = notes.read_text().splitlines()
    if not lines or lines[0] != "# GMSetzer " + version or not any(line.strip() for line in lines[1:]):
        raise ValueError("release notes must have a final matching title and nonempty body")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    args = parser.parse_args()
    try:
        validate_release(Path(__file__).resolve().parents[1], args.tag)
    except (ValueError, OSError) as error:
        parser.exit(1, str(error) + "\n")
    print(f"Release identity and final notes match {args.tag}.")


if __name__ == "__main__":
    main()
