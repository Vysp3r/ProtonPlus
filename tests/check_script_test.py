#!/usr/bin/env python3

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent


class CheckCommandTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.project = Path(self.temporary_directory.name) / "project with spaces"
        (self.project / "scripts").mkdir(parents=True)
        (self.project / "tests").mkdir()
        shutil.copy2(PROJECT_ROOT / "scripts" / "check.sh", self.project / "scripts")
        self.bin_directory = self.project / "bin"
        self.bin_directory.mkdir()
        self.log_path = self.project / "commands.jsonl"
        self.build_directory = self.project / "custom build"
        self.environment = os.environ.copy()
        self.environment.update(
            PATH=f"{self.bin_directory}{os.pathsep}{self.environment['PATH']}",
            BUILD_DIR="custom build",
            PROTONPLUS_CHECK_LOG=str(self.log_path),
        )
        self.write_executable(self.bin_directory / "meson", """#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

with open(os.environ['PROTONPLUS_CHECK_LOG'], 'a') as log:
    log.write(json.dumps(['meson', str(Path.cwd()), sys.argv[1:]]) + '\\n')
if sys.argv[1] == 'setup':
    marker = Path(sys.argv[2]) / 'meson-private' / 'coredata.dat'
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.touch()
if os.environ.get('PROTONPLUS_FAIL_COMMAND') == sys.argv[1]:
    sys.exit(23)
""")
        self.write_executable(self.bin_directory / "git", """#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

with open(os.environ['PROTONPLUS_CHECK_LOG'], 'a') as log:
    log.write(json.dumps(['git', str(Path.cwd()), sys.argv[1:]]) + '\\n')
if os.environ.get('PROTONPLUS_FAIL_COMMAND') == 'git':
    sys.exit(24)
""")
        self.write_executable(
            self.build_directory / "tests" / "protonplus-tests",
            """#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

listing = '-l' in sys.argv
command = 'unit-list' if listing else 'unit-tests'
with open(os.environ['PROTONPLUS_CHECK_LOG'], 'a') as log:
    log.write(json.dumps([command, str(Path.cwd()), sys.argv[1:]]) + '\\n')
if os.environ.get('PROTONPLUS_FAIL_COMMAND') == command:
    sys.exit(26 if listing else 25)
if listing:
    print('TAP version 14')
    print('1..0' if os.environ.get('PROTONPLUS_EMPTY_TEST_PATH') == sys.argv[-1] else '1..1')
""",
        )

    @staticmethod
    def write_executable(path: Path, content: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        path.chmod(0o755)

    def run_check(self, *paths: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["bash", str(self.project / "scripts" / "check.sh"), *paths],
            cwd=self.temporary_directory.name,
            env=self.environment,
            capture_output=True,
            text=True,
        )

    def commands(self) -> list:
        if not self.log_path.exists():
            return []
        return [json.loads(line) for line in self.log_path.read_text().splitlines()]

    def test_full_check_sets_up_once_and_preserves_paths_with_spaces(self) -> None:
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), [
            ["meson", str(self.project), ["setup", str(self.build_directory)]],
            ["meson", str(self.project), ["compile", "-C", str(self.build_directory)]],
            ["meson", str(self.project), [
                "test", "-C", str(self.build_directory), "--no-rebuild", "--print-errorlogs",
            ]],
            ["git", str(self.project), ["diff", "--check"]],
        ])
        self.log_path.unlink()
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(command[2][0] == "setup" for command in self.commands()))

    def test_focused_paths_use_fixture_working_directory(self) -> None:
        result = self.run_check("/web", "/web/persistent")
        self.assertEqual(result.returncode, 0, result.stderr)
        unit_commands = [command for command in self.commands() if command[0].startswith("unit-")]
        self.assertEqual(unit_commands, [
            ["unit-list", str(self.project / "tests"), ["--tap", "-l", "-p", "/web"]],
            ["unit-tests", str(self.project / "tests"), ["-p", "/web"]],
            ["unit-list", str(self.project / "tests"), ["--tap", "-l", "-p", "/web/persistent"]],
            ["unit-tests", str(self.project / "tests"), ["-p", "/web/persistent"]],
        ])
        self.assertFalse(any(command[0] == "meson" and command[2][0] == "test"
                             for command in self.commands()))

    def test_named_download_area_includes_nested_tests(self) -> None:
        result = self.run_check("downloads")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = [command for command in self.commands() if command[0].startswith("unit-")]
        self.assertEqual(commands, [
            ["unit-list", str(self.project / "tests"), ["--tap", "-l", "-r", "/web"]],
            ["unit-tests", str(self.project / "tests"), ["-r", "/web"]],
        ])

    def test_native_build_and_checks_share_directory(self) -> None:
        shutil.copy2(PROJECT_ROOT / "scripts" / "build.sh", self.project / "scripts")
        (self.project / "data").mkdir()
        (self.project / "data" / "com.vysp3r.ProtonPlus.gschema.xml").write_text("<schemalist/>")
        for command in ("ninja", "glib-compile-schemas"):
            self.write_executable(self.bin_directory / command, "#!/bin/sh\nexit 0\n")
        # Exercise the default as well as the existing BUILD_DIR override.
        del self.environment["BUILD_DIR"]
        self.build_directory = self.project / "build"
        result = subprocess.run(
            ["bash", str(self.project / "scripts" / "build.sh"), "native"],
            cwd=self.temporary_directory.name, env=self.environment,
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        setups = [command for command in self.commands() if command[0] == "meson" and command[2][0] == "setup"]
        self.assertEqual(len(setups), 1)
        self.assertEqual(setups[0][2][1], str(self.build_directory))
        compiles = [command[2][2] for command in self.commands() if command[0] == "meson" and command[2][0] == "compile"]
        self.assertEqual(compiles, [str(self.build_directory), str(self.build_directory)])

    def test_failures_stop_the_check_and_preserve_exit_status(self) -> None:
        for failed_command, expected_status, paths in [
            ("setup", 23, []),
            ("compile", 23, []),
            ("test", 23, []),
            ("unit-list", 26, ["/cli", "/providers"]),
            ("unit-tests", 25, ["/cli", "/providers"]),
            ("git", 24, []),
        ]:
            with self.subTest(command=failed_command):
                if self.log_path.exists():
                    self.log_path.unlink()
                self.environment["PROTONPLUS_FAIL_COMMAND"] = failed_command
                result = self.run_check(*paths)
                self.assertEqual(result.returncode, expected_status, result.stderr)
                last_command = self.commands()[-1]
                actual_command = last_command[2][0] if last_command[0] == "meson" else last_command[0]
                self.assertEqual(actual_command, failed_command)

    def test_empty_selection_fails_before_executing_tests(self) -> None:
        self.environment["PROTONPLUS_EMPTY_TEST_PATH"] = "/missing"
        result = self.run_check("/missing")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("No GLib tests match: /missing", result.stderr)
        self.assertFalse(any(command[0] in ("unit-tests", "git")
                             for command in self.commands()))

    def test_invalid_selection_fails_before_any_build(self) -> None:
        result = self.run_check("unknown-area")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("starting with /", result.stderr)
        self.assertEqual(self.commands(), [])


if __name__ == "__main__":
    unittest.main()
