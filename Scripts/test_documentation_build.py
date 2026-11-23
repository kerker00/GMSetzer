import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("build_documentation", Path(__file__).with_name("build_documentation.py"))
docs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(docs)


class DocumentationGraphTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name)

    def compiler(self, command, check):
        # Model the Swift 6.2 regression: package-wide extraction attempts to
        # load an unbuilt test runner. Library compilation can emit its graphs.
        if "dump-symbol-graph" in command:
            raise subprocess.CalledProcessError(1, command, stderr="Couldn't load module 'GMSetzerPackageTests'")
        if "-symbol-graph-skip-synthesized-members" in command:
            raise subprocess.CalledProcessError(1, command, stderr="unknown argument on Swift 6.2")
        self.assertEqual(command[command.index("--target") + 1], "GMSetzer")
        fresh = Path(command[command.index("-emit-symbol-graph-dir") + 2])
        for module in self.modules:
            (fresh / f"{module}.symbols.json").write_text(json.dumps({"module": {"name": module}, "symbols": []}))

    def test_library_docs_do_not_require_a_test_runner_module(self):
        self.modules = docs.MODULES
        graphs = docs.emit_library_graphs(self.output, self.output, 2, run=self.compiler)
        self.assertEqual({p.stem for p in graphs.glob("*.json")}, {name + ".symbols" for name in docs.MODULES})

    def test_old_graphs_cannot_conceal_an_incomplete_current_export(self):
        self.modules = docs.MODULES
        docs.emit_library_graphs(self.output, self.output, 2, run=self.compiler)
        self.modules = docs.MODULES[:-1]
        with self.assertRaises(FileNotFoundError):
            docs.emit_library_graphs(self.output, self.output, 2, run=self.compiler)

    def test_a_compilation_failure_is_not_ignored(self):
        self.modules = docs.MODULES
        docs.emit_library_graphs(self.output, self.output, 2, run=self.compiler)

        def failed(command, check):
            raise subprocess.CalledProcessError(1, command)

        with self.assertRaises(subprocess.CalledProcessError):
            docs.emit_library_graphs(self.output, self.output, 2, run=failed)
