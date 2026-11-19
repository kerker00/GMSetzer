from dataclasses import replace
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import check_benchmark_budget as gate


class BenchmarkBudgetTests(unittest.TestCase):
    data = Path(__file__).resolve().parents[1] / 'Docs/BenchmarkData/M1-B'
    script = Path(__file__).with_name('check_benchmark_budget.py')

    def recorded(self, stage='after'):
        return gate.parse_results((self.data / f'{stage}.md').read_text())

    def test_recorded_regression_is_detected_and_checked_optimisation_passes(self):
        before = gate.evaluate(self.recorded('before'))
        after = gate.evaluate(self.recorded())
        self.assertEqual(len(before['failures']), 3)
        self.assertTrue(all(not row['budget_passed'] for row in before['cases'] if row['profile'] == 'CommonMark'))
        self.assertEqual(after['failures'], [])
        self.assertEqual(len(after['cases']), 6)

    def test_time_units_convert_to_the_same_duration(self):
        for unit, value in [('ns', 3_000_000), ('μs', 3000), ('µs', 3000), ('ms', 3), ('s', 0.003)]:
            with self.subTest(unit=unit):
                text = ('### GMSetzer CommonMark parse 100 KB (bytes: 100284, corpus: mixed-v1)\n'
                        f'| Time (wall clock) ({unit}) * | 0 | 0 | {value} | 0 | 0 | 0 | 0 | 10 |\n')
                timing = gate.parse_results(text)[('GMSetzer', 'CommonMark', '100 KB')]
                self.assertAlmostEqual(timing.milliseconds, 3.0)

    def test_ratio_boundary_is_inclusive_but_absolute_limit_is_strict(self):
        results = self.recorded()
        key = ('GMSetzer', 'CommonMark', '100 KB')
        reference = results[('cmark-gfm (C)', 'CommonMark', '100 KB')]
        results[key] = replace(results[key], milliseconds=2 * reference.milliseconds)
        self.assertEqual(gate.evaluate(results)['failures'], [])
        results[key] = replace(results[key], milliseconds=2 * reference.milliseconds + 0.001)
        self.assertEqual(len(gate.evaluate(results)['failures']), 1)
        results[key] = replace(results[key], milliseconds=10.0)
        results[('cmark-gfm (C)', 'CommonMark', '100 KB')] = replace(reference, milliseconds=10.0)
        self.assertEqual(len(gate.evaluate(results)['failures']), 1)

    def test_incomplete_duplicate_invalid_and_nonmatching_inputs_are_rejected(self):
        results = self.recorded()
        key = ('cmark-gfm (C)', 'CommonMark', '1 MB')
        for change in [dict(byte_count=1), dict(corpus='different-v1')]:
            changed = dict(results)
            changed[key] = replace(results[key], **change)
            with self.assertRaises(ValueError):
                gate.evaluate(changed)
        del results[key]
        with self.assertRaises(ValueError):
            gate.evaluate(results)
        raw = (self.data / 'after.md').read_text()
        with self.assertRaises(ValueError):
            gate.parse_results(raw + raw)
        for value in ['nan', 'inf', '-1', '0']:
            with self.assertRaises(ValueError):
                gate.parse_results('### GMSetzer CommonMark parse 100 KB (bytes: 100284, corpus: mixed-v1)\n'
                                   f'| Time (wall clock) (ms) * | 0 | 0 | {value} | 0 | 0 | 0 | 0 | 10 |\n')
        with self.assertRaises(ValueError):
            gate.parse_results(raw.replace('(μs)', '(unsupported)'))

    def test_regression_tolerance_requires_same_baseline_case_and_explicit_percentage(self):
        baseline = self.recorded()
        current = dict(baseline)
        key = ('GMSetzer', 'CommonMark', '1 MB')
        current[key] = replace(current[key], milliseconds=current[key].milliseconds * 1.2)
        report = gate.evaluate(current, baseline, 10)
        self.assertTrue(all(row['budget_passed'] for row in report['cases']))
        self.assertEqual(len(report['failures']), 1)
        for percentage in [None, -1, float('nan'), float('inf')]:
            with self.assertRaises(ValueError):
                gate.evaluate(current, baseline, percentage)
        baseline[key] = replace(baseline[key], name=baseline[key].name + ' changed')
        with self.assertRaises(ValueError):
            gate.evaluate(current, baseline, 10)

    def test_cli_exit_status_distinguishes_pass_failure_and_invalid_data(self):
        for stage, expected in [('before', 1), ('after', 0)]:
            result = subprocess.run([sys.executable, '-I', str(self.script), str(self.data / f'{stage}.md')],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, expected, result.stderr)
            self.assertEqual(len(json.loads(result.stdout)['cases']), 6)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'invalid.md'
            path.write_text('no benchmark results')
            result = subprocess.run([sys.executable, '-I', str(self.script), str(path)], capture_output=True)
            self.assertEqual(result.returncode, 2)


if __name__ == '__main__':
    unittest.main()
