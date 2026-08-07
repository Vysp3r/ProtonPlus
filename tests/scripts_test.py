#!/usr/bin/env python3

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from types import ModuleType


PROJECT_ROOT = Path(__file__).resolve().parent.parent


def load_script(name: str, filename: str) -> ModuleType:
    path = PROJECT_ROOT / "scripts" / filename
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f'Could not load "{path}".')

    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


set_version = load_script("set_version_script", "set-version.py")


class SetVersionTest(unittest.TestCase):
    def test_validates_semantic_versions(self) -> None:
        self.assertEqual(set_version.validate_version("1.2.3"), "1.2.3")
        self.assertEqual(set_version.validate_version("1.2.3-beta.1"), "1.2.3-beta.1")

        for invalid_version in (
            "1.2",
            "1.2.3-",
            "1.2.3.4",
            "version-1.2.3",
            "1..3",
        ):
            with self.subTest(version=invalid_version):
                with self.assertRaises(ValueError):
                    set_version.validate_version(invalid_version)

    def test_prepares_all_updates_before_writing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            project_root = Path(temporary_directory)
            (project_root / "meson.build").write_text(
                "project('example', version: '0.1.0')\n",
                encoding="utf-8",
            )
            (project_root / "com.vysp3r.ProtonPlus.yml").write_text(
                "tag: v0.1.0\n",
                encoding="utf-8",
            )

            updates = set_version.build_updates("1.2.3", project_root)
            updated_texts = [set_version.apply_update(update) for update in updates]

            self.assertIn("version: '1.2.3'", updated_texts[0])
            self.assertIn("tag: v1.2.3", updated_texts[1])


if __name__ == "__main__":
    unittest.main()
