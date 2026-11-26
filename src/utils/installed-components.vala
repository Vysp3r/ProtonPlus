namespace ProtonPlus.Utils {
    public interface ComponentDetectionBackend : Object {
        public abstract bool has_command (string name);
        public abstract CommandResult list_flatpaks ();
        public abstract bool has_vulkan_manifest (string relative_path, string? marker = null);
    }

    private class HostComponentDetectionBackend : Object, ComponentDetectionBackend {
        bool is_flatpak;

        public HostComponentDetectionBackend (bool is_flatpak) {
            this.is_flatpak = is_flatpak;
        }

        public bool has_vulkan_manifest (string relative_path, string? marker = null) {
            string[] roots = { "/etc", "/usr/local/etc", "/usr/local/share", "/usr/share" };
            if (is_flatpak)
                roots = { "/run/host/etc", "/run/host/usr/local/etc", "/run/host/usr/local/share", "/run/host/usr/share" };
            else {
                roots += Environment.get_user_config_dir ();
                roots += Environment.get_user_data_dir ();
                foreach (var root in Environment.get_system_config_dirs ())
                    roots += root;
                foreach (var root in Environment.get_system_data_dirs ())
                    roots += root;
            }
            foreach (var root in roots) {
                var path = Path.build_filename (root, "vulkan", relative_path);
                if (!FileUtils.test (path, FileTest.IS_REGULAR))
                    continue;
                if (marker == null)
                    return true;
                if (matches_vulkan_layer (path, marker))
                    return true;
            }
            return false;
        }

        bool matches_vulkan_layer (string path, string name_prefix) {
            try {
                var parser = new Json.Parser ();
                parser.load_from_file (path);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                    return false;
                var manifest = root.get_object ();
                if (!manifest.has_member ("layer"))
                    return false;
                var layer = manifest.get_member ("layer");
                if (layer.get_node_type () != Json.NodeType.OBJECT)
                    return false;
                var name = layer.get_object ().get_string_member_with_default ("name", "");
                var library = layer.get_object ().get_string_member_with_default ("library_path", "");
                if (!name.has_prefix (name_prefix) || library == "")
                    return false;
                if (Path.is_absolute (library))
                    return FileUtils.test (is_flatpak ? "/run/host" + library : library, FileTest.IS_REGULAR);
                return !library.contains ("/") || FileUtils.test (
                    Path.build_filename (Path.get_dirname (path), library), FileTest.IS_REGULAR
                );
            } catch (Error error) {
                return false;
            }
        }

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
        public bool proton_autogen { get; private set; }
        public bool mangohud { get; private set; }
        public bool mangoapp { get; private set; }
        public bool gamescope { get; private set; }
        public bool gamemode { get; private set; }
        public bool game_performance { get; private set; }
        public bool obs_vkcapture { get; private set; }
        public bool obs_gamecapture { get; private set; }
        public bool amd_vulkan_switcher { get; private set; }
        public string scopebuddy_command { get; private set; default = ""; }
        public bool scopebuddy { get; private set; }
        public bool vkbasalt { get; private set; }

        private Gee.HashSet<string> flatpak_ids = new Gee.HashSet<string> ();

        public InstalledComponents (bool is_flatpak, ComponentDetectionBackend? backend = null) {
            var detector = backend ?? new HostComponentDetectionBackend (is_flatpak);
            protontricks = detector.has_command ("protontricks");
            proton_autogen = detector.has_command ("proton-autogen");
            mangohud = detector.has_command ("mangohud");
            gamescope = detector.has_command ("gamescope");
            mangoapp = detector.has_command ("mangoapp");
            gamemode = detector.has_command ("gamemoderun");
            game_performance = detector.has_command ("game-performance");
            obs_gamecapture = detector.has_command ("obs-gamecapture");
            obs_vkcapture = detector.has_command ("obs-vkcapture")
                || detector.has_vulkan_manifest ("implicit_layer.d/obs_vkcapture_64.json")
                || detector.has_vulkan_manifest ("implicit_layer.d/obs_vkcapture_32.json");
            const string switchable_graphics = "VK_LAYER_AMD_switchable_graphics_";
            amd_vulkan_switcher =
                detector.has_vulkan_manifest ("implicit_layer.d/amd_icd64.json", switchable_graphics)
                || detector.has_vulkan_manifest ("implicit_layer.d/amd_icd32.json", switchable_graphics);
            if (detector.has_command ("scopebuddy"))
                scopebuddy_command = "scopebuddy";
            else if (detector.has_command ("scb"))
                scopebuddy_command = "scb";
            scopebuddy = scopebuddy_command != "";
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
