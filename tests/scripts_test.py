#!/usr/bin/env python3

import importlib.util
import os
import re
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
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


class SettingsSchemaContractTest(unittest.TestCase):
    def test_required_keys_match_schema_and_runtime_usage(self) -> None:
        schema_root = ET.parse(
            PROJECT_ROOT / "data" / "com.vysp3r.ProtonPlus.gschema.xml"
        ).getroot()
        schema = schema_root.find("./schema[@id='com.vysp3r.ProtonPlus.State']")
        self.assertIsNotNone(schema)
        schema_keys = {key.attrib["name"] for key in schema.findall("key")}

        filesystem_source = (
            PROJECT_ROOT / "src" / "utils" / "filesystem.vala"
        ).read_text(encoding="utf-8")
        required_keys_match = re.search(
            r"REQUIRED_SCHEMA_KEYS\s*=\s*\{(?P<keys>.*?)\};",
            filesystem_source,
            re.DOTALL,
        )
        self.assertIsNotNone(required_keys_match)
        required_keys = set(re.findall(r'"([^"]+)"', required_keys_match.group("keys")))

        settings_call_pattern = re.compile(
            r"(?:ProtonPlus\.)?Globals\.SETTINGS\s*\.\s*"
            r"(?:get_(?:boolean|enum|string|int|uint|double|value)|"
            r"set_(?:boolean|enum|string|int|uint|double|value)|bind)"
            r"\s*\(\s*\"([^\"]+)\"",
            re.DOTALL,
        )
        settings_changed_pattern = re.compile(
            r'(?:ProtonPlus\.)?Globals\.SETTINGS\s*\.\s*changed\s*\[\s*"([^"]+)"\s*\]'
        )
        runtime_keys = set()
        for source_path in (PROJECT_ROOT / "src").rglob("*.vala"):
            source = source_path.read_text(encoding="utf-8")
            runtime_keys.update(settings_call_pattern.findall(source))
            runtime_keys.update(settings_changed_pattern.findall(source))

        self.assertSetEqual(required_keys, schema_keys)
        self.assertSetEqual(runtime_keys - required_keys, set())


class FlatpakManifestPermissionTest(unittest.TestCase):
    def test_redundant_and_private_detection_paths_are_absent(self) -> None:
        forbidden = {
            "--filesystem=xdg-data/flatpak:ro",
            "--filesystem=/var/lib/flatpak:ro",
            "--filesystem=~/.var/app/io.github.Faugus.faugus-launcher/config/faugus-launcher:ro",
            "--filesystem=~/.var/app/io.github.Faugus.faugus-launcher/data/faugus-launcher:ro",
            "--filesystem=~/.var/app/io.github.Faugus.faugus-launcher/.local/state/faugus-launcher:ro",
        }
        for filename in (
            "com.vysp3r.ProtonPlus.yml",
            "com.vysp3r.ProtonPlus.local.yml",
        ):
            with self.subTest(manifest=filename):
                content = (PROJECT_ROOT / filename).read_text(encoding="utf-8")
                permissions = {
                    match.group(1)
                    for match in re.finditer(r"^\s*-\s+(--filesystem=\S+)\s*$", content, re.MULTILINE)
                }
                self.assertTrue(forbidden.isdisjoint(permissions))
                self.assertNotIn("--filesystem=host-root", permissions)
                self.assertNotIn("--filesystem=xdg-data/flatpak", permissions)
                self.assertNotIn("--filesystem=/var/lib/flatpak", permissions)


class AppImagePackagingTest(unittest.TestCase):
    def test_restores_all_protonplus_catalogs_without_host_locale_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            test_root = Path(temporary_directory)
            locale_source = test_root / "locale source"
            appdir = test_root / "Generated AppDir"
            expected_catalogs = {}
            linguas = (PROJECT_ROOT / "po" / "LINGUAS").read_text(encoding="utf-8")
            locales = tuple(filter(None, linguas.splitlines()))

            for locale in locales:
                messages_directory = locale_source / locale / "LC_MESSAGES"
                messages_directory.mkdir(parents=True)
                catalog = messages_directory / "com.vysp3r.ProtonPlus.mo"
                catalog_content = f"{locale} ProtonPlus catalog".encode()
                catalog.write_bytes(catalog_content)
                expected_catalogs[locale] = catalog_content
                (messages_directory / "host-application.mo").write_bytes(b"unrelated")

            fake_bin = test_root / "bin"
            fake_bin.mkdir()
            self._write_executable(
                fake_bin / "uname",
                "#!/bin/sh\nprintf '%s\\n' x86_64\n",
            )
            self._write_executable(
                fake_bin / "meson",
                """#!/bin/sh
set -eu
if [ "$1" = introspect ]; then
    printf '%s\\n' '{"version":"0.0.0"}'
fi
""",
            )
            self._write_executable(
                fake_bin / "quick-sharun",
                """#!/bin/sh
set -eu
if [ "${1:-}" = --make-appimage ]; then
    catalog_count=$(find "$PROTONPLUS_APPIMAGE_APPDIR/share/locale" \\
        -type f -name 'com.vysp3r.ProtonPlus.mo' | wc -l)
    unrelated_count=$(find "$PROTONPLUS_APPIMAGE_APPDIR/share/locale" \\
        -type f -name 'host-application.mo' | wc -l)
    [ "$catalog_count" -eq "$PROTONPLUS_EXPECTED_CATALOG_COUNT" ]
    [ "$unrelated_count" -eq 0 ]
    touch "$PROTONPLUS_APPIMAGE_APPDIR/.made-appimage"
else
    rm -rf "$PROTONPLUS_APPIMAGE_APPDIR/share/locale"
    mkdir -p "$PROTONPLUS_APPIMAGE_APPDIR/share/locale"
fi
""",
            )

            environment = os.environ.copy()
            environment["PATH"] = f"{fake_bin}{os.pathsep}{environment['PATH']}"
            environment["PROTONPLUS_APPIMAGE_APPDIR"] = str(appdir)
            environment["PROTONPLUS_APPIMAGE_LOCALE_SOURCE"] = str(locale_source)
            environment["PROTONPLUS_EXPECTED_CATALOG_COUNT"] = str(len(locales))
            subprocess.run(
                ["/bin/sh", str(PROJECT_ROOT / "scripts" / "make-appimage.sh")],
                cwd=test_root,
                env=environment,
                check=True,
                capture_output=True,
                text=True,
            )

            packaged_files = {
                path.relative_to(appdir / "share" / "locale")
                for path in (appdir / "share" / "locale").rglob("*")
                if path.is_file()
            }
            expected_files = {
                Path(locale) / "LC_MESSAGES" / "com.vysp3r.ProtonPlus.mo"
                for locale in expected_catalogs
            }
            self.assertSetEqual(packaged_files, expected_files)
            for locale, expected_content in expected_catalogs.items():
                packaged_catalog = (
                    appdir
                    / "share"
                    / "locale"
                    / locale
                    / "LC_MESSAGES"
                    / "com.vysp3r.ProtonPlus.mo"
                )
                self.assertEqual(packaged_catalog.read_bytes(), expected_content)
            self.assertTrue((appdir / ".made-appimage").is_file())

    @staticmethod
    def _write_executable(path: Path, content: str) -> None:
        path.write_text(content, encoding="utf-8")
        path.chmod(0o755)


if __name__ == "__main__":
    unittest.main()
