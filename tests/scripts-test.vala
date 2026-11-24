namespace ScriptTests.Maintenance {
    const string MANIFEST = "com.vysp3r.ProtonPlus.yml";
    const string METAINFO = "data/com.vysp3r.ProtonPlus.metainfo.xml.in";
    const string RELEASE_NOTES = "<component><releases><release version=\"1.2.3\" date=\"2026-09-12\">" +
        "<description><p>A useful fix.</p></description></release>" +
        "<release version=\"1.2.2\" date=\"2026-09-01\"/></releases></component>";

    delegate void FileVisitor (File file) throws Error;

    void visit_files (File directory, FileVisitor visit) throws Error {
        var entries = directory.enumerate_children ("standard::name,standard::type",
            FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        FileInfo? info;
        while ((info = entries.next_file ()) != null) {
            var child = directory.get_child (info.get_name ());
            if (info.get_file_type () == FileType.DIRECTORY)
                visit_files (child, visit);
            else if (info.get_file_type () == FileType.REGULAR)
                visit (child);
        }
    }

    void copy_directory (Fixture fixture, string relative) throws Error {
        var project = File.new_for_path (".");
        visit_files (File.new_for_path (relative), (file) => fixture.copy (project.get_relative_path (file)));
    }

    void setup_version (Fixture fixture) throws Error {
        fixture.copy ("packaging/set-version.sh");
        write_text (fixture.path ("meson.build"), "project('example', version: '1.2.3')\n");
        write_text (fixture.path (MANIFEST), "tag: v1.2.3\n");
        write_text (fixture.path (METAINFO), RELEASE_NOTES);
    }

    HashTable<string, string> snapshot (Fixture fixture) throws Error {
        var files = new HashTable<string, string> (str_hash, str_equal);
        visit_files (File.new_for_path (fixture.checkout), (file) => {
            var path = file.get_path ();
            files.insert (path, read_text (path));
        });
        return files;
    }

    void expect_snapshot (Fixture fixture, HashTable<string, string> before) throws Error {
        var after = snapshot (fixture);
        require (before.size () == after.size (), "Version command changed the file list");
        foreach (var path in before.get_keys ())
            expect_text (after.lookup (path) ?? "File removed: " + path, before[path]);
    }

    void print_version (Fixture fixture) throws Error {
        setup_version (fixture);
        File.new_for_path (fixture.path (MANIFEST)).delete ();
        File.new_for_path (fixture.path (METAINFO)).delete ();
        var before = snapshot (fixture);
        var result = fixture.bash ("packaging/set-version.sh", { "--print-version" });
        result.expect_status (0);
        expect_text (result.output, "1.2.3\n");
        expect_snapshot (fixture, before);
    }

    void validate_versions (Fixture fixture) throws Error {
        setup_version (fixture);
        var before = snapshot (fixture);
        foreach (var version in new string[] { "1.2.3", "1.2.3-beta.1" }) {
            var result = fixture.bash ("packaging/set-version.sh", { version, "--dry-run" });
            result.expect_status (0);
            require (result.output.contains ("Would patch"), result.output);
            expect_snapshot (fixture, before);
        }
        foreach (var version in new string[] {
            "1.2", "1.2.3-", "1.2.3.4", "version-1.2.3", "1..3", "1.2.3;echo oops"
        }) {
            var result = fixture.bash ("packaging/set-version.sh", { version });
            result.expect_status (1);
            require (result.errors.contains ("Invalid version"), result.errors);
            expect_snapshot (fixture, before);
        }
    }

    void update_version_fields (Fixture fixture) throws Error {
        setup_version (fixture);
        var manifest = fixture.path (MANIFEST);
        write_text (manifest, "  tag: v1.2.3  # release source\nother: keep\n");
        foreach (var version in new string[] { "1.2.4-beta.1", "1.2.4" }) {
            fixture.bash ("packaging/set-version.sh", { version }).expect_status (0);
            expect_text (read_text (fixture.path ("meson.build")), "project('example', version: '%s')\n".printf (version));
            expect_text (read_text (manifest), "  tag: v%s  # release source\nother: keep\n".printf (version));
            expect_text (read_text (fixture.path (METAINFO)), RELEASE_NOTES);
        }
    }

    void invalid_version_arguments (Fixture fixture) throws Error {
        setup_version (fixture);
        var before = snapshot (fixture);
        fixture.bash ("packaging/set-version.sh").expect_status (1);
        foreach (var arguments in new string[] {
            "--dry-run", "1.2.3 --check --dry-run", "1.2.3 --print-version", "1.2.3 1.2.4", "--unknown"
        }) {
            fixture.bash ("packaging/set-version.sh", arguments.split (" ")).expect_status (1);
            expect_snapshot (fixture, before);
        }
    }

    void check_invalid_version_file (Fixture fixture, string name, string contents) throws Error {
        var path = fixture.path (name);
        var original = read_text (path);
        write_text (path, contents);
        var before = snapshot (fixture);
        var result = fixture.bash ("packaging/set-version.sh", { "1.2.5" });
        result.expect_status (1);
        require (result.errors.contains ("Expected one version field"), result.errors);
        expect_snapshot (fixture, before);
        write_text (path, original);
    }

    void invalid_version_fields (Fixture fixture) throws Error {
        setup_version (fixture);
        check_invalid_version_file (fixture, MANIFEST, "no tag here\n");
        check_invalid_version_file (fixture, MANIFEST, "tag: v1.2.3\ntag: v1.2.4\n");
        check_invalid_version_file (fixture, "meson.build", "version: '1.2.3', version: '1.2.4'\n");
    }

    bool setup_release_check (Fixture fixture) throws Error {
        if (Environment.find_program_in_path ("xmllint") == null) {
            Test.skip ("Release checks require xmllint");
            return false;
        }
        setup_version (fixture);
        return true;
    }

    void check_release (Fixture fixture) throws Error {
        if (!setup_release_check (fixture))
            return;
        var before = snapshot (fixture);
        var current = fixture.bash ("packaging/set-version.sh", { "--check" });
        var explicit_version = fixture.bash ("packaging/set-version.sh", { "1.2.3", "--check" });
        foreach (var result in new CommandResult[] { current, explicit_version }) {
            result.expect_status (0);
            require (result.output.contains ("1.2.3"), result.output);
        }
        expect_snapshot (fixture, before);
    }

    void release_mismatches (Fixture fixture) throws Error {
        if (!setup_release_check (fixture))
            return;
        var before = snapshot (fixture);
        var result = fixture.bash ("packaging/set-version.sh", { "1.2.4", "--check" });
        result.expect_status (1);
        foreach (var name in new string[] { "meson.build", MANIFEST, Path.get_basename (METAINFO) })
            require (result.errors.contains (name), result.errors);
        expect_snapshot (fixture, before);
    }

    void stale_release_manifest (Fixture fixture) throws Error {
        if (!setup_release_check (fixture))
            return;
        write_text (fixture.path (MANIFEST), "tag: v1.2.2\n");
        var result = fixture.bash ("packaging/set-version.sh", { "--check" });
        result.expect_status (1);
        require (result.errors.contains ("expected version \"1.2.3\", found \"1.2.2\""), result.errors);
    }

    void release_entry (Fixture fixture) throws Error {
        if (!setup_release_check (fixture))
            return;
        string[] entries = {
            "<release version=\"1.2.2\" date=\"2026-09-12\"/>",
            "<release version=\"1.2.3\" date=\"2026-02-30\"/>",
            "<release version=\"1.2.3\" date=\"2026-09-12\"/>",
            ""
        };
        string[] messages = { "newest release must", "valid YYYY-MM-DD date", "release notes", "missing release entry" };
        for (var index = 0; index < entries.length; index++) {
            write_text (fixture.path (METAINFO), "<component><releases>%s</releases></component>".printf (entries[index]));
            var result = fixture.bash ("packaging/set-version.sh", { "--check" });
            result.expect_status (1);
            require (result.errors.contains (messages[index]), result.errors);
        }
    }

    void noncalendar_release_dates (Fixture fixture) throws Error {
        if (!setup_release_check (fixture))
            return;
        foreach (var date in new string[] { "20260912", "2026-W37-6" }) {
            write_text (fixture.path (METAINFO), RELEASE_NOTES.replace ("2026-09-12", date));
            var before = snapshot (fixture);
            var result = fixture.bash ("packaging/set-version.sh", { "--check" });
            result.expect_status (1);
            require (result.errors.contains ("valid YYYY-MM-DD date"), result.errors);
            expect_snapshot (fixture, before);
        }
    }

    void malformed_release_xml (Fixture fixture) throws Error {
        if (!setup_release_check (fixture))
            return;
        write_text (fixture.path (METAINFO), "<component><releases>");
        var before = snapshot (fixture);
        var result = fixture.bash ("packaging/set-version.sh", { "--check" });
        require (result.status != 0, "The release check accepted malformed XML");
        expect_snapshot (fixture, before);
    }

    string[] regex_captures (Regex pattern, string text) throws RegexError {
        string[] values = {};
        MatchInfo match;
        for (pattern.match (text, 0, out match); match.matches (); match.next ())
            values += match.fetch (1);
        return values;
    }

    void settings_schema (Fixture fixture) throws Error {
        fixture.copy ("data/com.vysp3r.ProtonPlus.gschema.xml");
        var directory = fixture.path ("data");
        fixture.run ({ "glib-compile-schemas", "--strict", directory }).expect_status (0);
        var source = new SettingsSchemaSource.from_directory (directory, null, false);
        var schema = source.lookup ("com.vysp3r.ProtonPlus.State", false);
        require (schema != null, "Missing ProtonPlus state schema");

        var key_array = new Regex ("REQUIRED_SCHEMA_KEYS\\s*=\\s*\\{(.*?)\\};", RegexCompileFlags.DOTALL);
        var string_literal = new Regex ("\"([^\"]+)\"");
        var sources = regex_captures (key_array, read_text ("src/utils/filesystem.vala"));
        require (sources.length == 1, "Expected one required settings key array");
        var required = new HashTable<string, bool> (str_hash, str_equal);
        foreach (var key in regex_captures (string_literal, sources[0]))
            required.insert (key, true);
        require (required.size () == schema.list_keys ().length, "Required and installed schema key counts differ");
        foreach (var key in schema.list_keys ())
            require (required.contains (key), "Schema key missing from the required list: " + key);

        var access = new Regex ("Globals\\.SETTINGS\\s*\\.\\s*" +
            "(?:(?:get|set)_(?:boolean|enum|string|int|uint|double|value)|bind)\\s*\\(\\s*\"([^\"]+)\"");
        var subscriptions = new Regex ("Globals\\.SETTINGS\\s*\\.\\s*changed\\s*\\[\\s*\"([^\"]+)\"");
        visit_files (File.new_for_path ("src"), (file) => {
            if (!file.get_basename ().has_suffix (".vala"))
                return;
            var text = read_text (file.get_path ());
            foreach (var pattern in new Regex[] { access, subscriptions }) {
                foreach (var key in regex_captures (pattern, text))
                    require (required.contains (key), "%s uses unknown settings key %s".printf (file.get_path (), key));
            }
        });
    }

    void flatpak_permissions (Fixture fixture) throws Error {
        string[] forbidden = {
            "--filesystem=xdg-data/flatpak:ro", "--filesystem=/var/lib/flatpak:ro",
            "--filesystem=~/.var/app/io.github.Faugus.faugus-launcher/config/faugus-launcher:ro",
            "--filesystem=~/.var/app/io.github.Faugus.faugus-launcher/data/faugus-launcher:ro",
            "--filesystem=~/.var/app/io.github.Faugus.faugus-launcher/.local/state/faugus-launcher:ro",
            "--filesystem=host-root", "--filesystem=xdg-data/flatpak", "--filesystem=/var/lib/flatpak",
        };
        var permission = new Regex ("^\\s*-\\s+(--filesystem=\\S+)\\s*$", RegexCompileFlags.MULTILINE);
        foreach (var name in new string[] { MANIFEST, "com.vysp3r.ProtonPlus.local.yml" }) {
            foreach (var value in regex_captures (permission, read_text (name)))
                require (!(value in forbidden), "%s declares %s".printf (name, value));
        }
    }

    string[] translation_commands (Fixture fixture, bool update) throws Error {
        fixture.copy ("Makefile");
        foreach (var name in new string[] {
            "data/z.ui", "data/a.desktop.in", "data/nested/dialog.ui",
            METAINFO, "data/com.vysp3r.ProtonPlus.gschema.xml", "data/build/generated.ui",
            "src/z.vala", "src/nested/a.vala", "src/meson.build", "src/build/generated.vala", "po/POTFILES"
        }) {
            write_text (fixture.path (name), "old contents\n");
        }
        fixture.executable (Path.build_filename (fixture.bin, "meson"), """#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$PROTONPLUS_TEST_COMMANDS"
if [ "$1" = compile ]; then
    cp po/POTFILES "$PROTONPLUS_TEST_CATALOG_SOURCES"
fi
""");
        var catalog_sources = Path.build_filename (fixture.root, "catalog sources");
        var commands = Path.build_filename (fixture.root, "commands");
        fixture.launcher.setenv ("PROTONPLUS_TEST_CATALOG_SOURCES", catalog_sources, true);
        fixture.launcher.setenv ("PROTONPLUS_TEST_COMMANDS", commands, true);
        fixture.launcher.setenv ("BUILD_DIR", "custom build", true);
        var target = update ? "translations-update" : "translations";
        fixture.run ({ "make", "-C", fixture.checkout, target }).expect_status (0);

        var expected = "# This file is generated automatically. Do not edit.\n" +
            "data/a.desktop.in\ndata/nested/dialog.ui\ndata/z.ui\nsrc/nested/a.vala\nsrc/z.vala\n";
        expect_text (read_text (catalog_sources), expected);
        expect_text (read_text (fixture.path ("po/POTFILES")), expected);
        visit_files (File.new_for_path (fixture.path ("po")), (file) => {
            require (!file.get_basename ().has_prefix (".POTFILES."), "Temporary POTFILES remains");
        });
        return read_text (commands).strip ().split ("\n");
    }

    void extract_template (Fixture fixture) throws Error {
        var commands = translation_commands (fixture, false);
        require (commands.length == 2, string.joinv ("\n", commands));
        require (commands[0].has_prefix ("setup ") && commands[0].contains ("custom build"), commands[0]);
        require (commands[1].has_suffix (" com.vysp3r.ProtonPlus-pot"), commands[1]);
    }

    void update_catalogs (Fixture fixture) throws Error {
        var commands = translation_commands (fixture, true);
        require (commands.length == 3, string.joinv ("\n", commands));
        require (commands[1].has_suffix (" com.vysp3r.ProtonPlus-pot"), commands[1]);
        require (commands[2].has_suffix (" com.vysp3r.ProtonPlus-update-po"), commands[2]);
    }

    void appimage_dependencies (Fixture fixture) throws Error {
        fixture.executable (Path.build_filename (fixture.bin, "pacman"), "#!/bin/sh\nexit 0\n");
        fixture.executable (Path.build_filename (fixture.bin, "get-debloated-pkgs"),
            "#!/bin/sh\ntouch \"$DEBLOAT_CALLED\"\n");
        var installed = Path.build_filename (fixture.root, "debloat-called");
        fixture.launcher.setenv ("DEBLOAT_CALLED", installed, true);
        fixture.launcher.setenv ("SOURCE", "", true);
        string[] responses = {
            "exit 22", "printf 'x-ratelimit-remaining: 0\\r\\n'", "printf 'x-ratelimit-remaining: 20\\r\\n'"
        };
        var script = Path.build_filename (Environment.get_current_dir (), "packaging/appimage/get-dependencies.sh");
        for (var index = 0; index < responses.length; index++) {
            fixture.executable (Path.build_filename (fixture.bin, "curl"), "#!/bin/sh\n" + responses[index] + "\n");
            fixture.run ({ "sh", script }).expect_status (0);
            require (FileUtils.test (installed, FileTest.EXISTS) == (index == 2),
                "Unexpected optional package decision for " + responses[index]);
        }
    }

    void appimage_catalogs (Fixture fixture) throws Error {
        fixture.copy ("Makefile");
        fixture.copy ("packaging/set-version.sh");
        copy_directory (fixture, "packaging/appimage");
        fixture.copy (METAINFO);
        write_text (fixture.path ("meson.build"), "project('example', version: '0.0.0')\n");

        var locales = Path.build_filename (fixture.root, "locale source");
        var appdir = Path.build_filename (fixture.root, "Generated AppDir");
        var expected = new HashTable<string, string> (str_hash, str_equal);
        foreach (var locale in read_text ("po/LINGUAS").strip ().split ("\n")) {
            var filename = Path.build_filename (locale, "LC_MESSAGES", "com.vysp3r.ProtonPlus.mo");
            var catalog = locale + " ProtonPlus catalog";
            expected.insert (filename, catalog);
            write_text (Path.build_filename (locales, filename), catalog);
            write_text (Path.build_filename (locales, locale, "LC_MESSAGES", "host-application.mo"), "unrelated");
        }

        fixture.executable (Path.build_filename (fixture.bin, "uname"), "#!/bin/sh\nprintf '%s\\n' x86_64\n");
        fixture.executable (Path.build_filename (fixture.bin, "meson"), "#!/bin/sh\nexit 0\n");
        fixture.executable (Path.build_filename (fixture.bin, "quick-sharun"), """#!/bin/sh
set -eu
test "$VERSION" = 0.0.0
if [ "$1" = --make-appimage ]; then
    catalog_count=$(find "$PROTONPLUS_APPIMAGE_APPDIR/share/locale" \
        -type f -name 'com.vysp3r.ProtonPlus.mo' | wc -l)
    unrelated_count=$(find "$PROTONPLUS_APPIMAGE_APPDIR/share/locale" \
        -type f -name 'host-application.mo' | wc -l)
    [ "$catalog_count" -eq "$PROTONPLUS_EXPECTED_CATALOG_COUNT" ]
    [ "$unrelated_count" -eq 0 ]
    test -s "$PROTONPLUS_APPIMAGE_APPDIR/usr/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml"
    touch "$PROTONPLUS_APPIMAGE_APPDIR/.made-appimage"
else
    rm -rf "$PROTONPLUS_APPIMAGE_APPDIR/share/locale"
    mkdir -p "$PROTONPLUS_APPIMAGE_APPDIR/share/locale"
fi
""");
        fixture.launcher.setenv ("PROTONPLUS_APPIMAGE_APPDIR", appdir, true);
        fixture.launcher.setenv ("PROTONPLUS_APPIMAGE_LOCALE_SOURCE", locales, true);
        fixture.launcher.setenv ("PROTONPLUS_EXPECTED_CATALOG_COUNT", expected.size ().to_string (), true);
        fixture.run ({ "make", "-C", fixture.checkout, "package", "TARGET=appimage" }).expect_status (0);

        var packaged_locales = File.new_for_path (Path.build_filename (appdir, "share", "locale"));
        var count = 0;
        visit_files (packaged_locales, (file) => {
            var relative = packaged_locales.get_relative_path (file);
            require (expected.contains (relative), "Unexpected packaged locale file " + relative);
            expect_text (read_text (file.get_path ()), expected[relative]);
            count++;
        });
        require (count == expected.size (), "AppImage did not restore every catalog");
        require (FileUtils.test (Path.build_filename (appdir, ".made-appimage"), FileTest.IS_REGULAR),
            "AppImage was not generated");
        expect_text (read_text (Path.build_filename (appdir, "usr", "share", "metainfo",
            "com.vysp3r.ProtonPlus.metainfo.xml")), read_text (METAINFO));
    }

    struct NativeTarget {
        public string name;
        public string format;
        public string image;
    }

    void native_packages (Fixture fixture) throws Error {
        if (Environment.find_program_in_path ("git") == null) {
            Test.skip ("Git is required for the package source fixture");
            return;
        }

        fixture.copy ("Makefile");
        copy_directory (fixture, "packaging");
        write_text (fixture.path ("meson.build"), "project('example', version: '0.0.1')\n");
        write_text (fixture.path ("removed"), "");
        write_text (fixture.path ("replaced/outside-file"), "");
        write_text (fixture.path (".gitignore"), "/dist/\n/ignored\n");
        fixture.run ({ "git", "init", "-q", fixture.checkout }).expect_status (0);
        fixture.run ({ "git", "-C", fixture.checkout, "add", "." }).expect_status (0);

        var working_meson = "project('example', version: '0.0.0')\n";
        write_text (fixture.path ("meson.build"), working_meson);
        write_text (fixture.path ("new-source"), "");
        write_text (fixture.path ("ignored"), "");
        File.new_for_path (fixture.path ("removed")).delete ();
        File.new_for_path (fixture.path ("replaced/outside-file")).delete ();
        var replaced = File.new_for_path (fixture.path ("replaced"));
        replaced.delete ();
        write_text (Path.build_filename (fixture.root, "outside-file"), "");
        replaced.make_symbolic_link ("..");

        var engine = Path.build_filename (fixture.root, "container-engine");
        fixture.executable (engine, """#!/bin/sh
set -eu
for argument do
    case $argument in
        *:/input/*) cp "${argument%%:/input/*}" "$PROTONPLUS_TEST_ARCHIVE" ;;
    esac
done
printf '%s\n' "$@" > "$PROTONPLUS_TEST_CONTAINER_ARGS"
""");
        var archive = Path.build_filename (fixture.root, "source.tar.gz");
        var container_args = Path.build_filename (fixture.root, "container-args");
        fixture.launcher.setenv ("PROTONPLUS_CONTAINER_ENGINE", engine, true);
        fixture.launcher.setenv ("PROTONPLUS_TEST_ARCHIVE", archive, true);
        fixture.launcher.setenv ("PROTONPLUS_TEST_CONTAINER_ARGS", container_args, true);

        NativeTarget[] targets = {
            { "debian13", "deb", "docker.io/library/debian:13" },
            { "ubuntu26.04", "deb", "docker.io/library/ubuntu:26.04" },
            { "fedora45", "rpm", "registry.fedoraproject.org/fedora:45" },
            { "archlinux", "pkg.tar.zst", "ghcr.io/pkgforge-dev/archlinux:latest" },
        };
        foreach (var target in targets) {
            fixture.run ({ "make", "-C", fixture.checkout, "package", "TARGET=" + target.name }).expect_status (0);
            var arguments = read_text (container_args).strip ().split ("\n");
            require (fixture.path ("dist") + ":/output" in arguments, "Missing package output volume");
            require (arguments.length >= 8, "Incomplete container arguments");
            expect_lines (arguments[arguments.length - 8:arguments.length], {
                target.image, "bash", "/source/packaging/build-native-package.sh", target.format,
                target.name, "0.0.0", "/input/ProtonPlus-0.0.0-source.tar.gz", "/output",
            });
        }

        var prefix = "ProtonPlus-0.0.0/";
        var contents = fixture.run ({ "tar", "-xOzf", archive, prefix + "meson.build" });
        contents.expect_status (0);
        expect_text (contents.output, working_meson);
        var listing = fixture.run ({ "tar", "-tzf", archive });
        listing.expect_status (0);
        var names = listing.output.strip ().split ("\n");
        require (prefix + "new-source" in names, "New checkout source missing from archive");
        foreach (var name in new string[] { "removed", "ignored", "replaced/outside-file" })
            require (!(prefix + name in names), "Unexpected archive entry " + name);
        var symlink = fixture.run ({ "tar", "-tvzf", archive, prefix + "replaced" });
        symlink.expect_status (0);
        require (symlink.output.strip ().has_suffix (prefix + "replaced -> .."), symlink.output);

        var legacy_archive = Path.build_filename (fixture.root, "ProtonPlus-0.0.0-source.tar.gz");
        var legacy_path = prefix + "packaging/build.sh";
        write_text (Path.build_filename (fixture.root, legacy_path),
            read_text (fixture.path ("packaging/build-native-package.sh")));
        fixture.run ({ "tar", "-czf", legacy_archive, legacy_path }).expect_status (0);
        fixture.bash ("packaging/native-container.sh", { "build", "debian13", legacy_archive }).expect_status (0);
        require ("/source/packaging/build.sh" in read_text (container_args).strip ().split ("\n"),
            "Legacy source archive did not use its packaging script");
    }

    int main (string[] args) {
        Test.init (ref args);
        register ("/set-version/print", print_version);
        register ("/set-version/validate", validate_versions);
        register ("/set-version/update-fields", update_version_fields);
        register ("/set-version/invalid-arguments", invalid_version_arguments);
        register ("/set-version/invalid-fields", invalid_version_fields);
        register ("/release-check/current-and-explicit", check_release);
        register ("/release-check/mismatches", release_mismatches);
        register ("/release-check/stale-manifest", stale_release_manifest);
        register ("/release-check/entry", release_entry);
        register ("/release-check/invalid-date-formats", noncalendar_release_dates);
        register ("/release-check/malformed-xml", malformed_release_xml);
        register ("/contracts/settings-schema", settings_schema);
        register ("/contracts/flatpak-permissions", flatpak_permissions);
        register ("/translations/extract-template", extract_template);
        register ("/translations/update-catalogs", update_catalogs);
        register ("/appimage/dependencies", appimage_dependencies);
        register ("/appimage/catalogs", appimage_catalogs);
        register ("/native-packaging/checkout-and-legacy-archive", native_packages);
        return Test.run ();
    }
}
