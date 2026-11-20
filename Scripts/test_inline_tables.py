"""Offline reproducibility and pinned-input tests for generated inline tables."""
import hashlib
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent

class InlineTableTests(unittest.TestCase):
    def test_generated_tables_match_their_tracked_inputs(self):
        path = ROOT / 'Scripts/generate_inline_tables.py'
        spec = importlib.util.spec_from_file_location('generate_inline_tables', path)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        self.assertEqual(generator.generate(), (ROOT / 'Sources/SetzerParser/InlineTables.swift').read_text())

    def test_reference_data_stays_pinned(self):
        expected = {
            'cmark-entities.inc': '3932dfa630067813f47be6ae0072e1645c1183bde41140b51443f50857c88909',
            'CaseFolding-17.0.0.txt': 'ff8d8fefbf123574205085d6714c36149eb946d717a0c585c27f0f4ef58c4183',
        }
        for name, digest in expected.items():
            self.assertEqual(hashlib.sha256((ROOT / 'Scripts/Data' / name).read_bytes()).hexdigest(), digest)
