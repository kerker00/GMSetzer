"""Offline regression tests: python3 -I -m unittest discover -s Scripts."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parent
COMMONMARK_DIGEST = "d431b29d97b6f73e69d547109cf5081578fac931e72afe95639ebe766c1b2a20"
GFM_DIGEST = "7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c"


class SpecUpdateTests(unittest.TestCase):
    def run_update(self, tamper=None):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scripts = root / "Scripts"
            scripts.mkdir()
            resources = root / "Tests/SetzerSpecTests/Resources"
            resources.mkdir(parents=True)
            outputs = [resources / "commonmark-0.31.2.json", resources / "gfm-0.29.json"]
            for output in outputs:
                output.write_text("original fixture")

            commonmark = b'[{"example": 1}]'
            fence = "`" * 32
            gfm = f"# Paragraphs\n{fence} example\nhello\n.\n<p>hello</p>\n{fence}\n".encode()
            script = (SCRIPTS / "update-specs.sh").read_text()
            script = script.replace(COMMONMARK_DIGEST, hashlib.sha256(commonmark).hexdigest())
            script = script.replace(GFM_DIGEST, hashlib.sha256(gfm).hexdigest())
            (scripts / "update-specs.sh").write_text(script)
            shutil.copy(SCRIPTS / "convert-gfm-spec.py", scripts)
            (root / "commonmark.input").write_bytes(commonmark + (b"tampered" if tamper == "commonmark" else b""))
            (root / "gfm.input").write_bytes(gfm + (b"tampered" if tamper == "gfm" else b""))

            # Supply downloads locally; these tests never contact the network.
            mock_curl = root / "curl"
            mock_curl.write_text("""#!/bin/sh
case "$2" in
  */spec.json) cp "$SPEC_TEST_INPUT/commonmark.input" "$4" ;;
  */test/spec.txt) cp "$SPEC_TEST_INPUT/gfm.input" "$4" ;;
  *) exit 1 ;;
esac
""")
            mock_curl.chmod(0o755)
            environment = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", SPEC_TEST_INPUT=str(root))
            result = subprocess.run(["sh", str(scripts / "update-specs.sh")], cwd=root.parent,
                                    env=environment, capture_output=True, text=True, timeout=10)
            return result, [output.read_text() for output in outputs]

    def test_verified_downloads_replace_both_fixtures_from_another_directory(self):
        result, outputs = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs[0], '[{"example": 1}]')
        self.assertIn('"markdown": "hello\\n"', outputs[1])

    def test_changed_download_leaves_both_fixtures_untouched(self):
        for source in ["commonmark", "gfm"]:
            with self.subTest(source=source):
                result, outputs = self.run_update(tamper=source)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Unexpected contents", result.stderr)
                self.assertEqual(outputs, ["original fixture", "original fixture"])


if __name__ == "__main__":
    unittest.main()
