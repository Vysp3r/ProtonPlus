namespace ProtonPlus.Utils {
    public interface ComponentDetectionBackend : Object {
        public abstract bool has_command (string name);
        public abstract CommandResult list_flatpaks ();
    }

    private class HostComponentDetectionBackend : Object, ComponentDetectionBackend {
        public bool has_command (string name) {
            return System.check_dependency_sync (name);
        }

        public CommandResult list_flatpaks () {
            return System.run_command_sync_result ("flatpak list --all --columns=application");
        }
    }

    /// One startup snapshot; detection never runs from a component lookup.
    public class InstalledComponents : Object {
        public bool protontricks { get; private set; }
        public bool mangohud { get; private set; }
        public bool gamescope { get; private set; }
        public bool gamemode { get; private set; }
        public bool game_performance { get; private set; }
        public bool obs_vkcapture { get; private set; }
        public bool scopebuddy { get; private set; }
        public bool vkbasalt { get; private set; }

        private Gee.HashSet<string> flatpak_ids = new Gee.HashSet<string> ();

        public InstalledComponents (bool is_flatpak, ComponentDetectionBackend? backend = null) {
            var detector = backend ?? new HostComponentDetectionBackend ();
            protontricks = detector.has_command ("protontricks");
            mangohud = detector.has_command ("mangohud");
            gamescope = detector.has_command ("gamescope");
            gamemode = detector.has_command ("gamemoderun");
            game_performance = detector.has_command ("game-performance");
            obs_vkcapture = detector.has_command ("obs-gamecapture");
            scopebuddy = detector.has_command ("scopebuddy") || detector.has_command ("scb");
            vkbasalt = detector.has_command ("vkbasalt");

            // Native builds retain their existing command-only detection policy.
            if (!is_flatpak)
                return;
            var result = detector.list_flatpaks ();
            if (result.exit_status != 0)
                return;
            foreach (var line in result.stdout.split ("\n")) {
                var id = line.strip ();
                if (id != "")
                    flatpak_ids.add (id);
            }
        }

        public bool has_flatpak (string id) {
            return id != "" && flatpak_ids.contains (id);
        }
    }
}
