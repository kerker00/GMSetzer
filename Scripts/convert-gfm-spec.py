#!/usr/bin/env python3
"""Converts the GFM specification (spec.txt from cmark-gfm) into the JSON
format of the CommonMark specification: a list of examples with
markdown, html, example number, section and start/end lines, plus the
extension named in the example fence ("example table" -> "table").

Usage: python3 -I Scripts/convert-gfm-spec.py spec.txt > out.json
"""
import json
import re
import sys

FENCE = "`" * 32


def convert(text):
    examples = []
    section = None
    lines = text.split("\n")
    i = 0
    number = 0
    while i < len(lines):
        line = lines[i]
        heading = re.match(r"^#{1,6} (.*)$", line)
        if heading:
            section = heading.group(1).strip()
        if line.startswith(FENCE + " example"):
            extension = line[len(FENCE + " example"):].strip() or None
            start = i + 1
            i += 1
            markdown = []
            while lines[i] != ".":
                markdown.append(lines[i])
                i += 1
            i += 1
            html = []
            while lines[i] != FENCE:
                html.append(lines[i])
                i += 1
            number += 1
            examples.append({
                "markdown": ("\n".join(markdown) + "\n").replace("→", "\t") if markdown else "",
                "html": ("\n".join(html) + "\n").replace("→", "\t") if html else "",
                "example": number,
                "start_line": start,
                "end_line": i + 1,
                "section": section,
                "extension": extension,
            })
        i += 1
    return examples


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as source:
        json.dump(convert(source.read()), sys.stdout, ensure_ascii=False, indent=1)
