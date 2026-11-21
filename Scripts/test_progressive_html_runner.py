import json
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from check_progressive_html_budget import source_files


RUNNER = runpy.run_path(str(Path(__file__).resolve().parents[1] / "Tools/ProgressiveHTMLProbe/run-linux-matrix.py"))


class ProgressiveHTMLRunnerTests(unittest.TestCase):
    def test_runner_and_checker_cover_new_probe_sources_and_ignore_build_artifacts(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            names = {"Package.swift", "Sources/Example.swift", "Tools/ProgressiveHTMLProbe/Package.swift",
                     "Tools/ProgressiveHTMLProbe/Sources/Probe/main.swift", "Tools/ProgressiveHTMLProbe/Sources/Probe/Added.swift",
                     "Tools/ProgressiveHTMLProbe/run-linux-matrix.py", "Tools/ProgressiveHTMLProbe/Support/allocator.c"}
            ignored = "Tools/ProgressiveHTMLProbe/.build/Generated.swift"
            for name in names | {ignored}:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
            actual = {str(path.relative_to(root)) for path in RUNNER["measurement_files"](root)}
            self.assertEqual(actual, names)
            self.assertEqual(actual, source_files(root, include_measurement_tools=True))

    def test_instrumentation_mismatch_fails_without_assert_statements(self):
        for allocator in (None, Path("/test/allocator.so")):
            completed = SimpleNamespace(stdout=json.dumps({"allocation_interposition": allocator is None}), stderr="")
            with patch("subprocess.run", return_value=completed):
                with self.assertRaisesRegex(ValueError, "interposition"):
                    RUNNER["execute"](Path("/test/probe"), 100_000, "mixed", "syntax-off", "full", allocator=allocator)

    def test_runtime_messages_are_preserved_with_addresses_normalised(self):
        completed = SimpleNamespace(stdout=json.dumps({"allocation_interposition": False}), stderr="other warning at 0xABC123\n")
        with patch("subprocess.run", return_value=completed):
            _, warning = RUNNER["execute"](Path("/test/probe"), 100_000, "mixed", "syntax-off", "full")
        self.assertEqual(warning, "other warning at 0x<address>")

    @unittest.skipUnless(shutil.which("git"), "Git is needed for source provenance checks")
    def test_revision_and_runtime_dirty_state_follow_the_actual_checkout(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            def git(*args):
                return subprocess.check_output(["git", "-C", str(root), "-c", "commit.gpgsign=false",
                    "-c", "core.hooksPath=/dev/null", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                    *args], stderr=subprocess.STDOUT, text=True).strip()
            self.assertEqual(RUNNER["source_revision"](root), (None, None))
            git("init", "--template=", "-q")
            (root / "Sources").mkdir()
            (root / "Package.swift").write_text("// manifest")
            (root / "Sources/Example.swift").write_text("enum Example {}")
            git("add", "Package.swift", "Sources")
            git("commit", "-qm", "Initial test sources")
            revision = git("rev-parse", "HEAD")
            self.assertEqual(RUNNER["source_revision"](root), (revision, False))
            extra = root / "Sources/Extra.swift"
            extra.write_text("enum Extra {}")
            self.assertEqual(RUNNER["source_revision"](root), (revision, True))
            extra.unlink()
            (root / "Sources/Example.swift").write_text("enum Changed {}")
            git("add", "Sources")
            self.assertEqual(RUNNER["source_revision"](root), (revision, True))
            git("commit", "-qm", "Changed runtime")
            self.assertEqual(RUNNER["source_revision"](root), (git("rev-parse", "HEAD"), False))
            nested = root / "source-transfer"
            nested.mkdir()
            self.assertEqual(RUNNER["source_revision"](nested), (None, None))


if __name__ == "__main__":
    unittest.main()
