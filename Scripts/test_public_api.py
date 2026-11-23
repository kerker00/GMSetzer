import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("check_public_api", Path(__file__).with_name("check_public_api.py"))
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


class PublicAPICompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.entry = {"path": ["Renderer", "render(_:)"], "kind": "swift.method",
                      "declaration": "func render(_ source: String) -> String", "conformances": []}
        self.before = {"Example": {"render": self.entry}}

    def test_an_additive_method_does_not_invalidate_existing_clients(self):
        after = {"Example": {"render": self.entry, "prepare": dict(self.entry, path=["Renderer", "prepare(_:)"])}}
        self.assertEqual(api.incompatibilities(self.before, after), [])

    def test_a_removed_method_is_reported(self):
        self.assertEqual(api.incompatibilities(self.before, {"Example": {}}),
                         ["Removed: Example/Renderer.render(_:)"])

    def test_a_new_throwing_requirement_is_reported(self):
        after = {"Example": {"render": dict(self.entry, declaration="func render(_ source: String) throws -> String")}}
        self.assertEqual(api.incompatibilities(self.before, after), ["Changed: Example/Renderer.render(_:)"])

    def test_losing_a_protocol_conformance_is_reported(self):
        before = {"Example": {"render": dict(self.entry, conformances=["Sendable"])}}
        self.assertEqual(api.incompatibilities(before, self.before),
                         ["Lost conformance: Example/Renderer.render(_:)"])

    def test_an_added_enum_case_breaks_existing_exhaustive_switches(self):
        enum = dict(self.entry, path=["Mode"], kind="swift.enum", declaration="enum Mode")
        before = {"Example": {"mode": enum}}
        after = {"Example": {"mode": enum, "new": dict(self.entry, path=["Mode", "new"], kind="swift.enum.case")}}
        self.assertEqual(api.incompatibilities(before, after), ["Added case to existing enum: Example/Mode.new"])


if __name__ == "__main__":
    unittest.main()
