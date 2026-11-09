namespace AppTests.SteamLibraryDiagnosticsTest {
    using ProtonPlus.Models;

    private const int64 NOW = 1800000000;

    private class Fixture : Object {
        public string root;

        public Fixture () {
            try {
                root = DirUtils.make_tmp ("protonplus-steam-diagnostics-XXXXXX");
            } catch (FileError error) {
                assert_not_reached ();
            }
        }

        public void write (string relative, string content) {
            var path = Path.build_filename (root, relative);
            assert (DirUtils.create_with_parents (Path.get_dirname (path), 0700) == 0);
            try {
                FileUtils.set_contents (path, content);
            } catch (FileError error) {
                assert_not_reached ();
            }
        }

        public string manifest (uint appid, string dir, uint flags = 4, string buildid = "0") {
            var content = "\"AppState\" { \"appid\" \"%u\" \"name\" \"Tool %u\" \"installdir\" %s \"StateFlags\" \"%u\" \"buildid\" \"%s\" }".printf (
                appid, appid, ProtonPlus.Utils.VDF.VdfDocument.quote (dir), flags, buildid
            );
            write ("steamapps/appmanifest_%u.acf".printf (appid), content);
            return content;
        }

        public void log (string messages, int64 timestamp = NOW) {
            var prefix = new DateTime.from_unix_local (timestamp).format ("[%Y-%m-%d %H:%M:%S] ");
            var content = new StringBuilder ();
            foreach (var message in messages.split ("\n"))
                content.append (prefix + message + "\n");
            write ("logs/compat_log.txt", content.str);
        }

        public Gee.List<SteamRuntimeRepairCandidate> inspect (string[]? libraries = null) {
            return new SteamLibraryDiagnostics ().inspect_sync (root, libraries ?? new string[] {}, NOW);
        }

        public void clear () {
            var loop = new MainLoop ();
            ProtonPlus.Utils.Filesystem.delete_directory.begin (root, (obj, result) => {
                assert (ProtonPlus.Utils.Filesystem.delete_directory.end (result));
                loop.quit ();
            });
            loop.run ();
        }
    }

    public void register_tests () {
        Test.add_func ("/steam-library-diagnostics/completed-install-requires-usable-files", test_completed_install);
        Test.add_func ("/steam-library-diagnostics/missing-manifest-needs-positive-evidence", test_missing_manifest);
        Test.add_func ("/steam-library-diagnostics/updates-and-recovery-suppress-warnings", test_updates_and_recovery);
        Test.add_func ("/steam-library-diagnostics/stale-invalid-and-unknown-logs-are-ignored", test_log_boundaries);
        Test.add_func ("/steam-library-diagnostics/multiple-libraries-deduplicate-and-find-repairs", test_multiple_libraries);
        Test.add_func ("/steam-library-diagnostics/malformed-and-symlink-inputs-are-ignored", test_invalid_inputs);
        Test.add_func ("/steam-library-diagnostics/log-reads-use-bounded-tail", test_log_tail);
    }

    private void test_completed_install () {
        var fixture = new Fixture ();
        var original = fixture.manifest (4183110, "Runtime");
        fixture.manifest (1493710, "Proton", 4, "12345");
        fixture.write ("steamapps/common/Proton/toolmanifest.vdf", "\"manifest\" { \"version\" \"2\" }");
        // Proton's launcher is required in addition to its manifest.
        assert (fixture.inspect ().size == 2);
        fixture.write ("steamapps/common/Proton/proton", "#!/bin/sh\n");
        var issues = fixture.inspect ();
        assert (issues.size == 1);
        assert (issues[0].appid == 4183110);
        assert (issues[0].internal_title == "steamlinuxruntime_4");
        assert (issues[0].install_path == Path.build_filename (fixture.root, "steamapps/common/Runtime"));
        string after;
        try {
            FileUtils.get_contents (Path.build_filename (fixture.root, "steamapps/appmanifest_4183110.acf"), out after);
        } catch (FileError error) {
            assert_not_reached ();
        }
        assert (after == original);
        // The same failure can have a nonzero build ID.
        fixture.manifest (4183110, "Runtime", 4, "12345");
        assert (fixture.inspect ().size == 1);
        fixture.write ("steamapps/common/Runtime/toolmanifest.vdf", "\"manifest\" { \"version\" \"2\" }");
        assert (fixture.inspect ().size == 0);
        fixture.clear ();
    }

    private void test_missing_manifest () {
        var fixture = new Fixture ();
        // No library registration, manifest, or files: absence alone is normal.
        assert (fixture.inspect ().size == 0);
        fixture.log ("Failed to load manifest for tool 4183110!\nTool 4183110 \"Steam Linux Runtime 4.0\" unsupported version 0.");
        var issues = fixture.inspect ();
        assert (issues.size == 1);
        assert (issues[0].appid == 4183110);
        assert (issues[0].display_title == "Steam Linux Runtime 4.0");
        assert (issues[0].install_path == "");
        assert (fixture.inspect ().size == 1);
        fixture.clear ();
    }

    private void test_updates_and_recovery () {
        var fixture = new Fixture ();
        fixture.log ("Failed to load manifest for tool 4183110!");
        fixture.manifest (4183110, "Runtime", 4 | 1024);
        assert (fixture.inspect ().size == 0);
        fixture.manifest (4183110, "Runtime", 1024);
        assert (fixture.inspect ().size == 0);
        fixture.manifest (4183110, "Runtime");
        assert (fixture.inspect ().size == 1);
        assert (FileUtils.remove (Path.build_filename (fixture.root, "steamapps/appmanifest_4183110.acf")) == 0);
        fixture.log ("Failed to load manifest for tool 4183110!\nCommand prefix for tool 4183110 set to: /fixture/run");
        assert (fixture.inspect ().size == 0);
        fixture.log ("Failed to load manifest for tool 4183110!\nLoaded manifest for tool steamlinuxruntime_4.");
        assert (fixture.inspect ().size == 0);
        fixture.log ("Command prefix for tool 4183110 set to: /fixture/run\nFailed to load manifest for tool 4183110!");
        assert (fixture.inspect ().size == 1);
        fixture.clear ();
    }

    private void test_log_boundaries () {
        var fixture = new Fixture ();
        fixture.log ("Failed to load manifest for tool 4183110!", NOW - 2 * 24 * 60 * 60);
        assert (fixture.inspect ().size == 0);
        fixture.log ("Failed to load manifest for tool 4183110!", NOW + 60);
        assert (fixture.inspect ().size == 0);
        fixture.log ("Failed to load manifest for tool 42!\nFailed to load manifest for tool 41831100!\nTool 4183110 \"Runtime\" unsupported version 1.");
        assert (fixture.inspect ().size == 0);
        fixture.write ("logs/compat_log.txt", "[invalid] Failed to load manifest for tool 4183110!\nFailed to load manifest for tool 4183110!\n");
        assert (fixture.inspect ().size == 0);
        fixture.clear ();
    }

    private void test_multiple_libraries () {
        var first = new Fixture ();
        var second = new Fixture ();
        first.manifest (4183110, "Runtime");
        second.manifest (4183110, "Runtime");
        var libraries = new string[] { first.root, second.root, second.root };
        assert (first.inspect (libraries).size == 1);
        second.write ("steamapps/common/Runtime/toolmanifest.vdf", "\"manifest\" { \"version\" \"2\" }");
        assert (first.inspect (libraries).size == 0);
        // Logs and findings remain scoped to their own Steam installation.
        first.log ("Failed to load manifest for tool 1493710!");
        assert (first.inspect (libraries).size == 1);
        assert (second.inspect ().size == 0);
        first.clear ();
        second.clear ();
    }

    private void test_invalid_inputs () {
        var fixture = new Fixture ();
        fixture.manifest (4183110, "../escape");
        fixture.write ("steamapps/appmanifest_1493710.acf", "\"AppState\" {");
        fixture.write ("steamapps/appmanifest_42.acf", "\"AppState\" { \"appid\" \"42\" \"StateFlags\" \"4\" }");
        assert (fixture.inspect ().size == 0);
        fixture.write ("outside.acf", "\"AppState\" { \"appid\" \"4183110\" \"installdir\" \"Runtime\" \"StateFlags\" \"4\" }");
        var path = Path.build_filename (fixture.root, "steamapps/appmanifest_4183110.acf");
        assert (FileUtils.remove (path) == 0);
        assert (Posix.symlink (Path.build_filename (fixture.root, "outside.acf"), path) == 0);
        assert (fixture.inspect ().size == 0);
        fixture.log ("Failed to load manifest for tool 4183110!");
        var log = Path.build_filename (fixture.root, "logs/compat_log.txt");
        assert (FileUtils.rename (log, log + ".outside") == 0);
        assert (Posix.symlink (log + ".outside", log) == 0);
        assert (fixture.inspect ().size == 0);
        fixture.clear ();
    }

    private void test_log_tail () {
        var fixture = new Fixture ();
        fixture.log ("Failed to load manifest for tool 4183110!");
        var path = Path.build_filename (fixture.root, "logs/compat_log.txt");
        string failure;
        try {
            FileUtils.get_contents (path, out failure);
        } catch (FileError error) {
            assert_not_reached ();
        }
        fixture.write ("logs/compat_log.txt", string.nfill (1024 * 1024 + 100, 'x') + "\n" + failure);
        assert (fixture.inspect ().size == 1);
        fixture.write ("logs/compat_log.txt", failure + string.nfill (1024 * 1024 + 100, 'x'));
        assert (fixture.inspect ().size == 0);
        fixture.clear ();
    }
}
