import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("check_release_version", Path(__file__).with_name("check_release_version.py"))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "Sources/SetzerSyntax").mkdir(parents=True)
        (self.root / "Docs/Releases").mkdir(parents=True)
        self.identity = self.root / "Sources/SetzerSyntax/LibraryIdentity.swift"
        self.identity.write_text('public static let current = "1.0.0"\n')
        self.notes = self.root / "Docs/Releases/1.0.0.md"
        self.notes.write_text("# GMSetzer 1.0.0\n\nRelease details.\n")

    def test_matching_final_release_is_accepted(self):
        release.validate_release(self.root, "v1.0.0")

    def test_a_development_identity_cannot_be_a_stable_tag(self):
        self.identity.write_text('public static let current = "1.0.0-dev.1"\n')
        with self.assertRaisesRegex(ValueError, "runtime identity"):
            release.validate_release(self.root, "v1.0.0")

    def test_draft_notes_cannot_be_published_as_final(self):
        self.notes.write_text("# GMSetzer 1.0.0 — draft\n\nPreparation.\n")
        with self.assertRaisesRegex(ValueError, "final matching title"):
            release.validate_release(self.root, "v1.0.0")

    def test_non_semver_or_path_tags_are_rejected(self):
        for tag in ["v01.0.0", "1.0.0", "v1.0", "v1.0.0-dev.1", "../1.0.0"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release.validate_release(self.root, tag)


if __name__ == "__main__":
    unittest.main()
