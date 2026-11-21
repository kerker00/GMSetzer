import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from check_progressive_html_budget import evaluate, load_evidence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "Docs/BenchmarkData/m6-progressive-html/linux-arm64-2026-11-21"


class ProgressiveHTMLBudgetTests(unittest.TestCase):
    def setUp(self):
        self.rows = json.loads((EVIDENCE / "summary.json").read_text())

    def change_timing(self, row, stage, value):
        row["timing_samples_ms"][stage] = [value] * 8
        row[{"first_ready": "first_ready_ms_p50", "all_groups": "all_groups_ms_p50"}[stage]] = value

    def test_archived_matrix_and_isolated_cli_pass(self):
        # Historical evidence remains testable when later runtime sources change.
        # Applying it to the current checkout is an explicit CLI validation step.
        self.assertEqual(evaluate(load_evidence(EVIDENCE))["failures"], [])
        result = subprocess.run([sys.executable, "-I", str(ROOT / "Scripts/check_progressive_html_budget.py"),
                                 str(EVIDENCE)], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(json.loads(result.stdout)["cases"]), 42)

    def test_a_fast_case_cannot_hide_another_cases_latency_or_completion_overrun(self):
        for stage in ("first_ready", "all_groups"):
            rows = copy.deepcopy(self.rows)
            row = next(row for row in rows if row["case"] == "mixed-1000000-syntax-off")
            self.change_timing(row, stage, 2 * row["full_ms_p50"])
            report = evaluate(rows)
            self.assertEqual(len(report["failures"]), 1)
            self.assertIn(row["case"], report["failures"][0])

    def test_giant_block_has_no_latency_target_but_still_has_a_completion_target(self):
        row = next(row for row in self.rows if row["case"] == "long-code-5000000-syntax-off")
        self.change_timing(row, "first_ready", 2 * row["full_ms_p50"])
        self.assertEqual(evaluate(self.rows)["failures"], [])
        self.change_timing(row, "all_groups", 2 * row["full_ms_p50"])
        self.assertEqual(evaluate(self.rows)["failures"], [row["case"] + ": completion"])

    def test_missing_duplicate_cases_and_incomplete_or_nonfinite_samples_are_rejected(self):
        for rows in (self.rows[:-1], self.rows[:-1] + [self.rows[0]]):
            with self.assertRaises(ValueError):
                evaluate(rows)
        for invalid in (-1, 0, True, "1", float("nan"), float("inf")):
            rows = copy.deepcopy(self.rows)
            rows[0]["timing_samples_ms"]["full"][0] = invalid
            with self.assertRaises(ValueError):
                evaluate(rows)
        self.rows[0]["timing_samples_ms"]["full"].pop()
        with self.assertRaises(ValueError):
            evaluate(self.rows)

    def test_changed_configuration_or_summary_cannot_silently_pass(self):
        for key, value in (("syntax_details", True), ("source_bytes", 1), ("plan_mode", "wholeDocument(rawHTML)"),
                           ("groups", 1), ("full_ms_p50", 1)):
            rows = copy.deepcopy(self.rows)
            rows[0][key] = value
            with self.assertRaises(ValueError):
                evaluate(rows)

    def test_peak_memory_regression_is_checked_for_first_and_complete_consumption(self):
        for mode in ("first", "groups"):
            rows = copy.deepcopy(self.rows)
            row = rows[0]
            high = 2 * row["rss_kib_p50"]["full"] + 8192
            row["rss_kib"][mode] = [high] * 3
            row["rss_kib_p50"][mode] = high
            self.assertEqual(evaluate(rows)["failures"], [row["case"] + ": peak_rss"])

    def test_corrupted_archives_and_changed_source_are_rejected(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            evidence = root / "evidence"
            shutil.copytree(EVIDENCE, evidence)
            with self.assertRaisesRegex(ValueError, "measured source changed"):
                (root / "Package.swift").write_text("changed")
                load_evidence(evidence, root)
            (evidence / "summary.json").write_text("[]")
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                load_evidence(evidence)
            # Updating a summary's checksum cannot hide disagreement with raw samples.
            rows = copy.deepcopy(self.rows)
            self.change_timing(rows[0], "first_ready", 0.1)
            (evidence / "summary.json").write_text(json.dumps(rows))
            hashes = json.loads((evidence / "sha256.json").read_text())
            hashes["summary.json"] = hashlib.sha256((evidence / "summary.json").read_bytes()).hexdigest()
            (evidence / "sha256.json").write_text(json.dumps(hashes))
            with self.assertRaisesRegex(ValueError, "raw timing/summary mismatch"):
                load_evidence(evidence)


if __name__ == "__main__":
    unittest.main()
