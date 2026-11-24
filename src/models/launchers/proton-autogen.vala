namespace ProtonPlus.Models.Launchers {
    public class ProtonAutogen : Launcher {
        public const string FAMILY_ID = "proton-autogen";
        private Steam native_steam;
        private string profiles_directory;
        private string proton_directory;
        private uint scan_generation;
        private uint library_generation;

        public bool command_installed { get; private set; }

        public ProtonAutogen (Steam native_steam, string? home_override = null, bool? command_installed = null) {
            var home = home_override ?? Environment.get_home_dir ();
            var steam_root = native_steam.directory != ""
                ? native_steam.directory : Path.build_filename (home, ".local", "share", "Steam");
            var profiles = Path.build_filename (home, ".config", "proton-autogen", "games");
            base ("Proton-Autogen", InstallationTypes.SYSTEM, Config.RESOURCE_BASE + "/proton-autogen.png", {},
                FAMILY_ID, {}, steam_root, Steam.FAMILY_ID, "steam-system");
            this.native_steam = native_steam;
            profiles_directory = profiles;
            proton_directory = native_steam.directory != "" ? native_steam.get_managed_compatibility_tools_root ()
                : Path.build_filename (steam_root, "compatibilitytools.d");
            this.command_installed = command_installed ?? Globals.PROTON_AUTOGEN_INSTALLED;
            installed = this.command_installed || FileUtils.test (profiles, FileTest.IS_DIR);
            has_library_support = true;
        }

        public override SteamRestartTarget? get_steam_restart_target () {
            return native_steam.get_steam_restart_target ();
        }

        public override void register_compatibility_tool_from_path (string tool_path) {
            if (native_steam.installed)
                native_steam.register_compatibility_tool_from_path (tool_path);
            foreach (var group in native_steam.groups)
                group.invalidate_installed_state ();
        }

        public override void unregister_compatibility_tool_by_path (string tool_path) {
            if (native_steam.installed)
                native_steam.unregister_compatibility_tool_by_path (tool_path);
            foreach (var group in native_steam.groups)
                group.invalidate_installed_state ();
        }

        public override string get_primary_managed_tool_directory (Group group) {
            return proton_directory;
        }

        public override async bool ensure_group_directory (string group_directory) {
            return FileUtils.test (proton_directory, FileTest.IS_DIR)
                || (yield Utils.Filesystem.create_directory_async (proton_directory));
        }

        public override bool supports_provider_definition (Providers.ProviderDefinition definition) {
            switch (definition.provider_id) {
            case "proton-ge":
            case "proton-cachyos":
            case "dw-proton":
            case "proton-ge-rtsp":
            case "proton-tkg":
            case "proton-em":
            case "proton-cachyos-wineland":
                return true;
            default:
                return false;
            }
        }

        public override string get_default_game_tool_title () {
            return _ ("Automatic");
        }

        public override async bool load_game_library () {
            var generation = ++library_generation;
            Gee.List<Utils.ProtonAutogenProfile>? profiles = null;
            SourceFunc callback = load_game_library.callback;
            new Thread<void> ("proton-autogen-profiles", () => {
                try {
                    profiles = Utils.ProtonAutogenConfig.read_profiles (profiles_directory);
                } catch (Error error) {
                    debug ("Could not read Proton-Autogen profiles: %s", error.message);
                }
                Idle.add ((owned) callback);
            });
            yield;

            if (profiles == null || generation != library_generation)
                return false;
            var discovered_games = new List<Game> ();
            foreach (var profile in profiles)
                discovered_games.append (new Games.ProtonAutogen (profile, this));
            games = (owned) discovered_games;
            yield refresh_game_compatibility_tools ();
            return true;
        }

        public override async bool refresh_game_compatibility_tools () {
            var generation = ++scan_generation;
            SourceFunc callback = refresh_game_compatibility_tools.callback;
            Gee.LinkedList<CompatibilityTool>? tools = null;
            new Thread<void> ("proton-autogen-tools", () => {
                tools = scan_proton_directory (proton_directory);
                Idle.add ((owned) callback);
            });
            yield;

            if (generation != scan_generation || tools == null)
                return false;
            compatibility_tools = tools;
            foreach (var game in games) {
                var autogen_game = (Games.ProtonAutogen) game;
                autogen_game.refresh_tool_selection ();
                var selected = game.compatibility_tool;
                if (selected == "Default" || find_game_tool (selected) != null)
                    continue;
                var label = Path.is_absolute (selected) ? Path.get_basename (selected) : selected;
                compatibility_tools.add (new CompatibilityTool (_ ("%s (Unavailable)").printf (label), selected) {
                    is_available = false, is_assignable = false
                });
            }
            return true;
        }

        private static Gee.LinkedList<CompatibilityTool> scan_proton_directory (string directory) {
            var tools = new Gee.LinkedList<CompatibilityTool> ();
            try {
                var entries = Dir.open (directory);
                string? name;
                while ((name = entries.read_name ()) != null) {
                    var lower_name = name.ascii_down ();
                    // Older ProtonPlus builds registered an Autogen adapter as a Steam tool.
                    if (!name.validate () || name.has_prefix (".") || name.has_suffix (" Backup") || !lower_name.contains ("proton") ||
                        lower_name.has_prefix ("proton-autogen"))
                        continue;
                    var path = Path.build_filename (directory, name);
                    if (!has_proton_executable (path))
                        continue;
                    tools.add (new CompatibilityTool (name, name, path, CompatibilityToolRuntimeKind.PROTON,
                        Posix.realpath (path) ?? path));
                }
            } catch (FileError error) {
                debug ("Could not scan the shared Proton directory: %s", error.message);
            }
            return tools;
        }

        private static bool has_proton_executable (string path) {
            var proton = Path.build_filename (path, "proton");
            return FileUtils.test (proton, FileTest.IS_REGULAR) && FileUtils.test (proton, FileTest.IS_EXECUTABLE);
        }

        internal CompatibilityTool? find_game_tool (string id) {
            return compatibility_tools.first_match ((tool) => tool.internal_title == id);
        }

        internal static bool game_tool_remains_available (CompatibilityTool? tool) {
            return tool != null && tool.is_assignable && tool.is_available && has_proton_executable (tool.path);
        }

        internal string get_profile_tool_id (Utils.ProtonAutogenProfile profile) {
            if (profile.proton == "")
                return "Default";
            if (profile.resolved_proton_path != null) {
                foreach (var tool in compatibility_tools) {
                    if (tool.is_available && profile.resolved_proton_path == tool.inspection_path)
                        return tool.internal_title;
                }
            }
            return profile.proton;
        }
    }
}
