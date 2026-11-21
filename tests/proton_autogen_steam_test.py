import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ENTRY_POINT = Path(__file__).resolve().parents[1] / "data/proton-autogen-steam.py"


class SteamLauncherTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        wrapper = self.root / "compatibilitytools.d/Proton-Autogen Latest"
        module = wrapper / "proton_autogen"
        module.mkdir(parents=True)
        self.entry = wrapper / ENTRY_POINT.name
        shutil.copyfile(ENTRY_POINT, self.entry)
        (module / "__init__.py").touch()
        self.configured_root = self.root / "Configured tools"
        self.configured_root.mkdir()
        (module / "config.py").write_text(f"def load_proton_paths(): return [{str(self.configured_root)!r}]\n")
        self.loader = module / "loader.py"
        self.write_profile("GE-Proton11-13")
        self.env = dict(
            os.environ,
            HOME=str(self.root),
            STEAM_COMPAT_CLIENT_INSTALL_PATH=str(self.root),
            STEAM_COMPAT_LIBRARY_PATHS="",
            STEAM_COMPAT_DATA_PATH=str(self.root / "Steam prefix"),
            STEAM_COMPAT_TOOL_PATHS=f"{wrapper}:/steam/runtime",
            SteamAppId="1234",
        )

    def write_profile(self, proton):
        self.loader.write_text(
            "def load_game_config(exe):\n"
            "    assert exe.endswith('/Test Game.exe') and exe.startswith('/')\n"
            f"    return {{'proton': {proton!r}}}\n"
        )

    def make_runner(self, root, name, runtime):
        path = root / name
        path.mkdir()
        (path / "toolmanifest.vdf").write_text(f'"manifest"\n{{\n  "require_tool_appid" "{runtime}"\n}}\n')
        proton = path / "proton"
        proton.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "env = [os.environ[key] for key in ('STEAM_COMPAT_DATA_PATH', 'SteamAppId', 'STEAM_COMPAT_TOOL_PATHS')]\n"
            "print(json.dumps([sys.argv, os.getcwd(), env]))\n"
        )
        proton.chmod(0o755)
        return proton

    def launch(self, *args):
        return subprocess.run(
            [sys.executable, "-I", self.entry, *args], cwd=self.root, env=self.env,
            capture_output=True, text=True, check=False,
        )

    def test_profile_selection_preserves_steam_launch(self):
        self.make_runner(self.entry.parent.parent, "Proton-CachyOS11", "4183110")
        chosen = self.make_runner(self.configured_root, "GE-Proton11-13", "4183110")
        args = ["waitforexitandrun", "Test Game.exe", "--version", "argument with spaces", "", "literal;argument"]
        result = self.launch(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"Proton-Autogen: using {chosen.parent}", result.stderr)
        argv, cwd, env = json.loads(result.stdout)
        self.assertEqual(argv, [str(chosen), *args])
        self.assertEqual(cwd, str(self.root))
        self.assertEqual(env, [self.env["STEAM_COMPAT_DATA_PATH"], "1234",
                               f"{chosen.parent}:{self.env['STEAM_COMPAT_TOOL_PATHS']}"])

    def test_reports_missing_compatible_runner(self):
        self.make_runner(self.configured_root, "GE-Proton11-13", "1628350")
        result = self.launch("run", "Test Game.exe")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Steam Linux Runtime 4.0", result.stderr)

    def test_uses_proton_path_saved_by_upstream_editor(self):
        chosen = self.make_runner(self.root, "Proton beside the game", "4183110")
        self.write_profile(str(chosen.parent))
        result = self.launch("run", "Test Game.exe")
        self.assertEqual(result.returncode, 0, result.stderr)
        argv, _, _ = json.loads(result.stdout)
        self.assertEqual(argv[0], str(chosen))

    def test_missing_preference_falls_back_to_proton_ge_latest(self):
        self.write_profile(str(self.root / "GE-Proton11-12"))
        self.make_runner(self.configured_root, "Proton - Experimental", "4183110")
        chosen = self.make_runner(self.entry.parent.parent, "Proton-GE Latest", "4183110")
        result = self.launch("waitforexitandrun", "Test Game.exe")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("preferred Proton build", result.stderr)
        self.assertIn("is unavailable", result.stderr)
        argv, _, _ = json.loads(result.stdout)
        self.assertEqual(argv[0], str(chosen))

    def test_newest_version_is_selected_within_a_family(self):
        self.write_profile("")
        self.make_runner(self.configured_root, "GE-Proton11-9.2", "4183110")
        chosen = self.make_runner(self.configured_root, "GE-Proton11-10", "4183110")
        result = self.launch("run", "Test Game.exe")
        self.assertEqual(result.returncode, 0, result.stderr)
        argv, _, _ = json.loads(result.stdout)
        self.assertEqual(argv[0], str(chosen))

    def test_preferred_alias_is_kept_when_it_shares_a_runner(self):
        chosen = self.make_runner(self.entry.parent.parent, "GE-Proton11-13", "4183110")
        alias = self.entry.parent.parent / "Preferred Proton alias"
        alias.symlink_to(chosen.parent)
        self.write_profile(alias.name)
        result = self.launch("run", "Test Game.exe")
        self.assertEqual(result.returncode, 0, result.stderr)
        argv, _, _ = json.loads(result.stdout)
        self.assertEqual(argv[0], str(alias / "proton"))

    def test_latest_slot_is_ranked_by_installed_version(self):
        self.write_profile("")
        self.make_runner(self.configured_root, "GE-Proton11-13", "4183110")
        chosen = self.make_runner(self.entry.parent.parent, "Proton-GE Latest", "4183110")
        (chosen.parent / "version").write_text("1732490018 GE-Proton11-15\n")
        result = self.launch("run", "Test Game.exe")
        self.assertEqual(result.returncode, 0, result.stderr)
        argv, _, _ = json.loads(result.stdout)
        self.assertEqual(argv[0], str(chosen))

    def test_unreadable_profile_can_still_launch(self):
        self.loader.write_text("raise PermissionError('fixture profile directory')\n")
        chosen = self.make_runner(self.entry.parent.parent, "GE-Proton11-13", "4183110")
        result = self.launch("run", "Test Game.exe")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("could not load the game profile", result.stderr)
        argv, _, _ = json.loads(result.stdout)
        self.assertEqual(argv[0], str(chosen))


if __name__ == "__main__":
    unittest.main()
