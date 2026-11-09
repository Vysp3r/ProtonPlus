namespace AppTests.SystemPathTest {
    using GLib;
    using ProtonPlus.Utils;

    private class FixtureComponentDetectionBackend : Object, ComponentDetectionBackend {
        public Gee.HashSet<string> commands = new Gee.HashSet<string> ();
        public Gee.HashMap<string, int> command_calls = new Gee.HashMap<string, int> ();
        public CommandResult flatpaks;
        public int flatpak_calls { get; private set; default = 0; }

        public FixtureComponentDetectionBackend (CommandResult flatpaks) {
            this.flatpaks = flatpaks;
        }

        public bool has_command (string name) {
            command_calls.set (name, command_calls.get (name) + 1);
            return commands.contains (name);
        }

        public CommandResult list_flatpaks () {
            flatpak_calls++;
            return flatpaks;
        }
    }

    public void register_tests () {
        Test.add_func ("/system/file-uri-escapes-special-characters", test_file_uri_escapes_special_characters);
        Test.add_func ("/system/flatpak-dependency/installed-branches", test_flatpak_installed_branches);
        Test.add_func ("/system/flatpak-dependency/exact-id", test_flatpak_exact_id);
        Test.add_func ("/system/flatpak-dependency/command-status", test_flatpak_command_status);
        Test.add_func ("/system/components/native-command-detection", test_native_command_detection);
        Test.add_func ("/system/components/flatpak-snapshot", test_flatpak_snapshot);
        Test.add_func ("/system/components/scopebuddy-alias", test_scopebuddy_alias);
    }

    private const string MANGOHUD_ID = "org.freedesktop.Platform.VulkanLayer.MangoHud";

    private bool has_dependency (string stdout, string stderr = "", int exit_status = 0) {
        var backend = new FixtureComponentDetectionBackend (
            new CommandResult (stdout, stderr, exit_status)
        );
        return new InstalledComponents (true, backend).has_flatpak (MANGOHUD_ID);
    }

    private void test_flatpak_installed_branches () {
        assert (!has_dependency (""));
        assert (has_dependency (MANGOHUD_ID + "\n"));
        // Different branches/installations can produce the same application ID.
        assert (has_dependency (MANGOHUD_ID + "\n" + MANGOHUD_ID + "\n"));
        assert (has_dependency ("com.valvesoftware.Steam\n" + MANGOHUD_ID));
    }

    private void test_flatpak_exact_id () {
        assert (!has_dependency ("com.valvesoftware.Steam\n"));
        assert (!has_dependency (MANGOHUD_ID + ".Locale\n"));
        assert (!has_dependency ("prefix." + MANGOHUD_ID + "\n"));
        var backend = new FixtureComponentDetectionBackend (new CommandResult ("\n", "", 0));
        assert (!new InstalledComponents (true, backend).has_flatpak (""));
    }

    private void test_flatpak_command_status () {
        assert (!has_dependency (MANGOHUD_ID + "\n", "localized failure", 1));
        assert (!has_dependency ("", "spawn failed", -1));
        assert (!has_dependency ("", MANGOHUD_ID));
        assert (has_dependency (MANGOHUD_ID + "\n", "warning: error: diagnostic"));
    }

    private void test_native_command_detection () {
        var backend = new FixtureComponentDetectionBackend (new CommandResult (MANGOHUD_ID, "", 0));
        backend.commands.add ("protontricks");
        backend.commands.add ("gamemoderun");
        backend.commands.add ("obs-gamecapture");
        backend.commands.add ("scopebuddy");
        var components = new InstalledComponents (false, backend);

        assert (components.protontricks && components.gamemode && components.obs_vkcapture);
        assert (components.scopebuddy && !backend.command_calls.has_key ("scb"));
        assert (!components.mangohud && !components.gamescope && !components.game_performance);
        assert (!components.vkbasalt && !components.has_flatpak (MANGOHUD_ID));
        assert (backend.flatpak_calls == 0);
        foreach (var calls in backend.command_calls.values)
            assert (calls == 1);
    }

    private void test_flatpak_snapshot () {
        var backend = new FixtureComponentDetectionBackend (new CommandResult (
            MANGOHUD_ID + "\n" + MANGOHUD_ID + "\ncom.github.Matoking.protontricks\n" +
            "org.freedesktop.Platform.VulkanLayer.OBSVkCapture\n" +
            "com.obsproject.Studio.Plugin.OBSVkCapture\n", "", 0
        ));
        backend.commands.add ("gamescope");
        var components = new InstalledComponents (true, backend);
        assert (components.gamescope);
        assert (components.has_flatpak (MANGOHUD_ID));
        assert (components.has_flatpak ("com.github.Matoking.protontricks"));
        assert (components.has_flatpak ("org.freedesktop.Platform.VulkanLayer.OBSVkCapture"));
        assert (components.has_flatpak ("com.obsproject.Studio.Plugin.OBSVkCapture"));
        assert (!components.has_flatpak (MANGOHUD_ID + ".Locale"));
        assert (backend.flatpak_calls == 1);

        // Looking up several components reads the snapshot, never another host query.
        backend.flatpaks = new CommandResult ("", "", 0);
        backend.commands.clear ();
        assert (components.gamescope && components.has_flatpak (MANGOHUD_ID));
        assert (backend.flatpak_calls == 1);

        var failed = new FixtureComponentDetectionBackend (new CommandResult (MANGOHUD_ID, "failed", 1));
        failed.commands.add ("gamescope");
        var unavailable = new InstalledComponents (true, failed);
        assert (unavailable.gamescope && !unavailable.has_flatpak (MANGOHUD_ID));
        assert (failed.flatpak_calls == 1);
    }

    private void test_scopebuddy_alias () {
        var backend = new FixtureComponentDetectionBackend (new CommandResult ("", "", 0));
        backend.commands.add ("scb");
        var components = new InstalledComponents (false, backend);
        assert (components.scopebuddy);
        assert (backend.command_calls.get ("scopebuddy") == 1);
        assert (backend.command_calls.get ("scb") == 1);
    }

    private void test_file_uri_escapes_special_characters () {
        var path = Path.build_filename (
            Environment.get_tmp_dir (), "ProtonPlus folder", "#100%", "café"
        );
        var uri = ProtonPlus.Utils.System.file_uri_for_path (path);

        assert (uri.has_prefix ("file://"));
        assert (uri.contains ("%20"));
        assert (uri.contains ("%23"));
        assert (uri.contains ("%25"));
        assert (uri.contains ("%C3%A9"));
        assert (File.new_for_uri (uri).get_path () == path);
    }
}
