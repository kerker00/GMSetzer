import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("parser_comparison", Path(__file__).resolve().parents[1] / "Tools/ParserComparison/run.py")
comparison = importlib.util.module_from_spec(spec)
spec.loader.exec_module(comparison)


class ParserComparisonTests(unittest.TestCase):
    def test_structural_whitespace_and_void_spelling_are_equivalent(self):
        self.assertEqual(comparison.canonical_html(b"<ul>\n<li>x<br /></li>\n</ul>\n"),
                         comparison.canonical_html(b"<ul><li>x<br></li></ul>"))

    def test_inline_whitespace_and_attributes_remain_significant(self):
        for left, right in [(b"<p>a <em>b</em></p>", b"<p>a<em>b</em></p>"),
                            (b'<a href="a">x</a>', b'<a href="b">x</a>')]:
            self.assertNotEqual(comparison.canonical_html(left), comparison.canonical_html(right))

    def test_nested_list_boundary_formatting_does_not_hide_inline_spacing(self):
        self.assertEqual(comparison.canonical_html(b"<ul><li><em>x</em>\n<ul><li>y</li></ul></li></ul>"),
                         comparison.canonical_html(b"<ul><li><em>x</em><ul><li>y</li></ul></li></ul>"))
        self.assertNotEqual(comparison.canonical_html(b"<ul><li><em>x</em> <em>y</em></li></ul>"),
                            comparison.canonical_html(b"<ul><li><em>x</em><em>y</em></li></ul>"))

    def test_preformatted_whitespace_and_unicode_are_preserved(self):
        self.assertNotEqual(comparison.canonical_html(b"<pre><code>x\n</code></pre>"),
                            comparison.canonical_html(b"<pre><code>x</code></pre>"))
        self.assertNotEqual(comparison.canonical_html("<p>é</p>".encode()),
                            comparison.canonical_html("<p>e\u0301</p>".encode()))

    def test_invalid_html_is_rejected(self):
        for html in [b"<p>", b"</p>", b"<p><em>x</p>", b"\xff"]:
            with self.assertRaises((ValueError, UnicodeError)):
                comparison.canonical_html(html)

    def test_integer_adapter_metrics_are_validated(self):
        data = {"elapsed_ns": 1000, "iterations": 2, "observed": 42}
        self.assertEqual(comparison.metric(json.dumps(data), 2), data)

    def test_invalid_or_mismatched_adapter_metrics_are_rejected(self):
        for data in [{"elapsed_ns": 0, "iterations": 1, "observed": 1},
                     {"elapsed_ns": True, "iterations": 1, "observed": 1},
                     {"elapsed_ns": 1.5, "iterations": 1, "observed": 1},
                     {"elapsed_ns": 100, "iterations": 2, "observed": 1},
                     {"elapsed_ns": 100, "iterations": 1, "observed": -1},
                     {"elapsed_ns": 100, "iterations": 1, "observed": 1, "extra": 2}]:
            with self.assertRaises(ValueError):
                comparison.metric(json.dumps(data), 1)
