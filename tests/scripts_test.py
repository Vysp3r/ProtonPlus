#!/usr/bin/env python3

import os
import re
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent


class VersionScriptFixture(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name) / "checkout with spaces"
        self.root.mkdir()
        (self.root / "scripts").mkdir()
        shutil.copy(PROJECT_ROOT / "scripts" / "set-version.sh", self.root / "scripts")
        (self.root / "meson.build").write_text(
            "project('example', version: '1.2.3')\n", encoding="utf-8"
        )
        (self.root / "com.vysp3r.ProtonPlus.yml").write_text(
            "tag: v1.2.3\n", encoding="utf-8"
        )
        (self.root / "data").mkdir()
        self.metainfo = self.root / "data" / "com.vysp3r.ProtonPlus.metainfo.xml.in"
        self.metainfo.write_text(
            '<component><releases><release version="1.2.3" date="2026-09-12">'
            '<description><p>A useful fix.</p></description></release>'
            '<release version="1.2.2" date="2026-09-01"/></releases></component>',
            encoding="utf-8",
        )

    def run_script(self, *arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["bash", str(self.root / "scripts" / "set-version.sh"), *arguments],
            cwd=self.root.parent,
            capture_output=True,
            text=True,
        )

    def snapshot(self) -> dict[Path, bytes]:
        return {path: path.read_bytes() for path in self.root.rglob("*") if path.is_file()}


class SetVersionTest(VersionScriptFixture):
    def test_validates_semantic_versions_without_writing(self) -> None:
        before = self.snapshot()
        for version in ("1.2.3", "1.2.3-beta.1"):
            with self.subTest(version=version):
                result = self.run_script(version, "--dry-run")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Would patch", result.stdout)
                self.assertEqual(self.snapshot(), before)

        for version in ("1.2", "1.2.3-", "1.2.3.4", "version-1.2.3", "1..3", "1.2.3;echo oops"):
            with self.subTest(version=version):
                result = self.run_script(version)
                self.assertEqual(result.returncode, 1)
                self.assertIn("Invalid version", result.stderr)
                self.assertEqual(self.snapshot(), before)

    def test_updates_only_version_fields_and_preserves_formatting(self) -> None:
        manifest = self.root / "com.vysp3r.ProtonPlus.yml"
        manifest.write_text("  tag: v1.2.3  # release source\nother: keep\n", encoding="utf-8")
        before_notes = self.metainfo.read_bytes()
        for version in ("1.2.4-beta.1", "1.2.4"):
            with self.subTest(version=version):
                result = self.run_script(version)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    (self.root / "meson.build").read_text(encoding="utf-8"),
                    f"project('example', version: '{version}')\n",
                )
                self.assertEqual(
                    manifest.read_text(encoding="utf-8"),
                    f"  tag: v{version}  # release source\nother: keep\n",
                )
                self.assertEqual(self.metainfo.read_bytes(), before_notes)

    def test_rejects_invalid_arguments_without_writing(self) -> None:
        before = self.snapshot()
        for arguments in (
            (),
            ("--dry-run",),
            ("1.2.3", "--check", "--dry-run"),
            ("1.2.3", "1.2.4"),
            ("--unknown",),
        ):
            with self.subTest(arguments=arguments):
                result = self.run_script(*arguments)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.snapshot(), before)

    def test_bad_fields_do_not_partially_update_files(self) -> None:
        for filename, contents in (
            ("com.vysp3r.ProtonPlus.yml", "no tag here\n"),
            ("com.vysp3r.ProtonPlus.yml", "tag: v1.2.3\ntag: v1.2.4\n"),
            ("meson.build", "version: '1.2.3', version: '1.2.4'\n"),
        ):
            with self.subTest(filename=filename, contents=contents):
                path = self.root / filename
                original = path.read_bytes()
                path.write_text(contents, encoding="utf-8")
                before = self.snapshot()
                result = self.run_script("1.2.5")
                self.assertEqual(result.returncode, 1)
                self.assertIn("Expected one version field", result.stderr)
                self.assertEqual(self.snapshot(), before)
                path.write_bytes(original)


@unittest.skipUnless(shutil.which("xmllint"), "release checks require xmllint")
class ReleaseCheckTest(VersionScriptFixture):
    def test_checks_current_and_explicit_versions_without_writing(self) -> None:
        before = self.snapshot()
        for arguments in (("--check",), ("1.2.3", "--check")):
            with self.subTest(arguments=arguments):
                result = self.run_script(*arguments)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("1.2.3", result.stdout)
                self.assertEqual(self.snapshot(), before)

    def test_reports_all_version_mismatches_without_writing(self) -> None:
        before = self.snapshot()
        result = self.run_script("1.2.4", "--check")
        self.assertEqual(result.returncode, 1)
        for filename in ("meson.build", "com.vysp3r.ProtonPlus.yml", self.metainfo.name):
            self.assertIn(filename, result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_rejects_stale_manifest_tag(self) -> None:
        (self.root / "com.vysp3r.ProtonPlus.yml").write_text(
            "tag: v1.2.2\n", encoding="utf-8"
        )
        result = self.run_script("--check")
        self.assertEqual(result.returncode, 1)
        self.assertIn('expected version "1.2.3", found "1.2.2"', result.stderr)

    def test_requires_newest_release_date_and_notes(self) -> None:
        for release, expected_error in (
            ('<release version="1.2.2" date="2026-09-12"/>', "newest release must"),
            ('<release version="1.2.3" date="2026-02-30"/>', "valid YYYY-MM-DD date"),
            ('<release version="1.2.3" date="2026-09-12"/>', "release notes"),
            ("", "missing release entry"),
        ):
            with self.subTest(release=release):
                self.metainfo.write_text(
                    f"<component><releases>{release}</releases></component>", encoding="utf-8"
                )
                result = self.run_script("--check")
                self.assertEqual(result.returncode, 1)
                self.assertIn(expected_error, result.stderr)

    def test_rejects_compact_and_week_dates(self) -> None:
        original = self.metainfo.read_text(encoding="utf-8")
        for release_date in ("20260912", "2026-W37-6"):
            with self.subTest(date=release_date):
                self.metainfo.write_text(
                    original.replace("2026-09-12", release_date), encoding="utf-8"
                )
                before = self.snapshot()
                result = self.run_script("--check")
                self.assertEqual(result.returncode, 1)
                self.assertIn("valid YYYY-MM-DD date", result.stderr)
                self.assertEqual(self.snapshot(), before)

    def test_rejects_malformed_xml_without_writing(self) -> None:
        self.metainfo.write_text("<component><releases>", encoding="utf-8")
        before = self.snapshot()
        result = self.run_script("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot(), before)


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


class TranslationBuildTest(unittest.TestCase):
    def check_translation_mode(self, *arguments: str) -> list:
        with tempfile.TemporaryDirectory() as temporary_directory:
            test_root = Path(temporary_directory)
            checkout = test_root / "checkout with spaces"
            (checkout / "scripts").mkdir(parents=True)
            shutil.copy(PROJECT_ROOT / "scripts" / "build.sh", checkout / "scripts")
            for filename in (
                "data/z.ui",
                "data/a.desktop.in",
                "data/nested/dialog.ui",
                "data/com.vysp3r.ProtonPlus.metainfo.xml.in",
                "data/com.vysp3r.ProtonPlus.gschema.xml",
                "data/build/generated.ui",
                "src/z.vala",
                "src/nested/a.vala",
                "src/meson.build",
                "src/build/generated.vala",
                "po/POTFILES",
            ):
                path = checkout / filename
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("old contents\n", encoding="utf-8")

            fake_bin = test_root / "bin"
            fake_bin.mkdir()
            stub = fake_bin / "meson"
            stub.write_text(
                "#!/bin/sh\nset -eu\n"
                "printf '%s\\n' \"$*\" >> \"$PROTONPLUS_TEST_COMMANDS\"\n"
                'if [ "$1" = compile ]; then\n'
                '    cp po/POTFILES "$PROTONPLUS_TEST_CATALOG_SOURCES"\n'
                "fi\n",
                encoding="utf-8",
            )
            stub.chmod(0o755)

            catalog_sources = test_root / "catalog sources"
            environment = os.environ.copy()
            environment["PATH"] = f"{fake_bin}{os.pathsep}{environment['PATH']}"
            environment["PROTONPLUS_TEST_CATALOG_SOURCES"] = str(catalog_sources)
            command_log = test_root / "commands"
            environment["PROTONPLUS_TEST_COMMANDS"] = str(command_log)
            environment["BUILD_DIR"] = "custom build"
            result = subprocess.run(
                ["bash", str(checkout / "scripts" / "build.sh"), "translations", *arguments],
                cwd=test_root,
                env=environment,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            expected_sources = (
                "# This file is generated automatically. Do not edit.\n"
                "data/a.desktop.in\n"
                "data/nested/dialog.ui\n"
                "data/z.ui\n"
                "src/nested/a.vala\n"
                "src/z.vala\n"
            )
            self.assertEqual(catalog_sources.read_text(encoding="utf-8"), expected_sources)
            self.assertEqual(
                (checkout / "po" / "POTFILES").read_text(encoding="utf-8"), expected_sources
            )
            self.assertFalse((checkout / "po" / "POTFILES.tmp").exists())

            return command_log.read_text().splitlines()

    def test_template_extraction_does_not_merge_or_compile_application(self) -> None:
        commands = self.check_translation_mode()
        self.assertEqual(len(commands), 2, commands)
        self.assertTrue(commands[0].startswith("setup "), commands)
        self.assertIn("custom build", commands[0])
        self.assertTrue(commands[1].endswith(" com.vysp3r.ProtonPlus-pot"), commands)

    def test_catalog_update_is_explicit_and_extracts_template_first(self) -> None:
        commands = self.check_translation_mode("update")
        self.assertEqual(len(commands), 3, commands)
        self.assertTrue(commands[1].endswith(" com.vysp3r.ProtonPlus-pot"), commands)
        self.assertTrue(commands[2].endswith(" com.vysp3r.ProtonPlus-update-po"), commands)


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
