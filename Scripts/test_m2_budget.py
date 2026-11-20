import contextlib
import dataclasses
import hashlib
import io
import json
from pathlib import Path
import tempfile
from unittest.mock import patch
import unittest

from check_benchmark_budget import Timing
from check_m2_budget import evaluate, main


class M2BudgetTests(unittest.TestCase):
    def setUp(self):
        self.limits = {"100 KB": 0.5, "1 MB": 8.0, "5 MB": 40.0}
        self.baseline = {}
        for size, gm, c, count in [("100 KB", 2, 2, 100000), ("1 MB", 20, 20, 1000000), ("5 MB", 100, 100, 5000000)]:
            for engine, time in [("GMSetzer", gm), ("cmark-gfm (C)", c)]:
                self.baseline[(engine, "CommonMark", size)] = Timing(engine + size, time, 20, count, "mixed-v1")

    def test_exact_allowance_passes_but_a_faster_small_case_cannot_hide_an_overrun(self):
        current = dict(self.baseline)
        for size, allowance in self.limits.items():
            key = ("GMSetzer", "CommonMark", size)
            current[key] = dataclasses.replace(current[key], milliseconds=current[key].milliseconds + allowance)
        self.assertEqual(evaluate(current, self.baseline, self.limits)["failures"], [])
        key = ("GMSetzer", "CommonMark", "1 MB")
        current[key] = dataclasses.replace(current[key], milliseconds=28.1)
        self.assertEqual(len(evaluate(current, self.baseline, self.limits)["failures"]), 1)

    def test_missing_changed_or_invalid_inputs_are_rejected(self):
        current = dict(self.baseline)
        current.pop(("GMSetzer", "CommonMark", "1 MB"))
        with self.assertRaises(ValueError): evaluate(current, self.baseline, self.limits)
        for attribute, value in [("byte_count", 999), ("corpus", "changed")]:
            current = dict(self.baseline)
            key = ("GMSetzer", "CommonMark", "1 MB")
            current[key] = dataclasses.replace(current[key], **{attribute: value})
            with self.assertRaises(ValueError): evaluate(current, self.baseline, self.limits)
        for invalid in [-1, float("nan"), float("inf"), True, "8"]:
            with self.assertRaises(ValueError): evaluate(self.baseline, self.baseline, dict(self.limits, **{"1 MB": invalid}))
        with self.assertRaises(ValueError): evaluate(self.baseline, self.baseline, {"1 MB": 8})

    def test_control_drift_is_not_counted_as_inline_headroom(self):
        current = dict(self.baseline)
        key = ("cmark-gfm (C)", "CommonMark", "1 MB")
        current[key] = dataclasses.replace(current[key], milliseconds=25)
        self.assertEqual(len(evaluate(current, self.baseline, self.limits)["failures"]), 1)

    def test_total_parse_ceiling_still_applies_with_a_large_allowance(self):
        current = dict(self.baseline)
        key = ("GMSetzer", "CommonMark", "1 MB")
        current[key] = dataclasses.replace(current[key], milliseconds=41)
        self.assertEqual(len(evaluate(current, self.baseline, dict(self.limits, **{"1 MB": 30}))["failures"]), 1)

    def test_cli_rejects_a_tampered_frozen_baseline(self):
        rows = []
        for (engine, profile, size), value in self.baseline.items():
            rows.append(f"### {engine} {profile} parse {size} (bytes: {value.byte_count}, corpus: {value.corpus})\n"
                        f"| Time (wall clock) (ms) * | 1 | 1 | {value.milliseconds} | 1 | 1 | 1 | 1 | 20 |\n")
        with tempfile.TemporaryDirectory() as scratch:
            baseline = Path(scratch) / "baseline.md"
            settings = Path(scratch) / "allowance.json"
            baseline.write_text("\n".join(rows))
            settings.write_text(json.dumps(dict(baseline_sha256=hashlib.sha256(baseline.read_bytes()).hexdigest(), additional_parse_ms=self.limits)))
            argv = ["check_m2_budget.py", str(baseline), "--baseline", str(baseline), "--allowance", str(settings)]
            with patch("sys.argv", argv), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main(), 0)
            baseline.write_text(baseline.read_text() + "\nChanged receipt\n")
            with patch("sys.argv", argv), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(main(), 2)
