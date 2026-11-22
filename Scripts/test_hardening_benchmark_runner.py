import importlib.util
from pathlib import Path
import re
import sys
import tempfile
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "Tools/run_hardening_benchmarks.py"
SPEC = importlib.util.spec_from_file_location("hardening_benchmark_runner", MODULE_PATH)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)

CASE = "GMSetzer m5-composed-v1 parse syntax-off 16 KiB (bytes: 16500, corpus: m5-composed-v1)"
RESULT = """## Baseline 'Current_run'
### {case}
| Metric | p0 | p25 | p50 | p75 | p90 | p99 | p100 | Samples |
| Malloc (bytes total) (M) * | 1 | 1 | 2 | 2 | 2 | 3 | 3 | 8 |
| Malloc (total) (K) * | 1 | 1 | 4 | 4 | 5 | 5 | 5 | 8 |
| Time (wall clock) (μs) * | 100 | 200 | 1234 | 1500 | 1600 | 1700 | 1800 | 8 |
"""


class HardeningBenchmarkRunnerTests(unittest.TestCase):
    def test_metrics_preserve_units_and_convert_time(self):
        result = runner.parse_result(RESULT.format(case=CASE), CASE)
        self.assertEqual(result["wall_ms_p50"], "1.234")
        self.assertEqual(result["metrics"]["Malloc (total) (K) *"]["p50_display"], "4")

    def test_failed_or_ambiguous_exports_are_not_samples(self):
        text = RESULT.format(case=CASE)
        for malformed in ("child crashed", text + text, text.replace(CASE, "another case"),
                          text.replace("| 1234 |", "| NaN |"),
                          text.replace("| 4 | 4 |", "| 0 | 4 |"),
                          text.replace("| 8 |", "| 0 |"), text + text.splitlines()[3],
                          text.replace("Malloc (bytes total)", "Malloc (total)")):
            with self.subTest(text=malformed):
                with self.assertRaises(ValueError):
                    runner.parse_result(malformed, CASE)

    def test_literal_filter_does_not_match_other_names(self):
        for name in (CASE, CASE.replace("GMSetzer", "cmark-gfm (C)")):
            with self.subTest(name=name):
                pattern = runner.exact_filter(name)
                base_name = name.split(" (bytes: ", 1)[0]
                self.assertIsNotNone(re.fullmatch(pattern, base_name))
                self.assertIsNone(re.fullmatch(pattern, base_name.replace("16 KiB", "64 KiB")))
                self.assertIsNone(re.fullmatch(pattern, name))

    def test_incomplete_listing_is_rejected(self):
        with self.assertRaises(ValueError):
            runner.case_names(CASE)

    def test_timeout_is_bounded_and_logs_survive(self):
        with tempfile.TemporaryDirectory() as directory:
            out, err = Path(directory) / "out", Path(directory) / "err"
            code, timed_out = runner.execute(
                [sys.executable, "-c", "import time; print('started', flush=True); time.sleep(30)"],
                out, err, timeout=0.5)
            self.assertTrue(timed_out)
            self.assertNotEqual(code, 0)
            self.assertEqual(out.read_text().strip(), "started")
