namespace ProtonPlus.Models.Launchers {
    public class Steam : Launcher {
        public const string FAMILY_ID = "steam";
        public List<SteamProfile> profiles;
        public SteamProfile profile { get; set; }
        public string default_compatibility_tool { get; set; }
        public HashTable<uint, string> compatibility_tool_hashtable;
        private Games.AwacyGameCatalog awacy_game_catalog;
        private SteamCompatibilityToolDiscovery compatibility_tool_discovery;
        private uint game_library_generation;

        public Steam (
            Launcher.InstallationTypes installation_type,
            Games.AwacyGameCatalog? awacy_game_catalog = null,
            SteamCompatibilityToolDiscovery? compatibility_tool_discovery = null
        ) {
            string[] directories = null;
            var custom_dir = Globals.SETTINGS != null
                ? Globals.SETTINGS.get_string ("steam-dir-custom").strip ()
                : "";

            switch (installation_type) {
                case Launcher.InstallationTypes.SYSTEM:
                    directories = new string[] {
                        "%s/Steam".printf (Environment.get_user_data_dir ()),
                        "%s/.local/share/Steam".printf (Environment.get_home_dir ()),
                        "%s/.steam/steam".printf (Environment.get_home_dir ()),
                        "%s/.steam/root".printf (Environment.get_home_dir ()),
                        "%s/.steam/debian-installation".printf (Environment.get_home_dir ()),
                        "/usr/share/steam",
                    };
                    break;
                case Launcher.InstallationTypes.FLATPAK:
                    directories = new string[] { "%s/.var/app/com.valvesoftware.Steam/data/Steam".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.SNAP:
                    directories = new string[] { "%s/snap/steam/common/.steam/root".printf (Environment.get_home_dir ()) };
                    break;
            }

            if (custom_dir.length > 0) {
                directories += custom_dir;
            }

            base ("Steam", installation_type, "%s/steam.svg".printf (Config.RESOURCE_BASE), directories, FAMILY_ID);

            has_library_support = true;
            profiles = new List<SteamProfile> ();
            default_compatibility_tool = "";
            compatibility_tool_hashtable = new HashTable<uint, string> (null, null);
            this.awacy_game_catalog = awacy_game_catalog ?? Games.AwacyGameCatalog.get_shared ();
            this.compatibility_tool_discovery = compatibility_tool_discovery
                ?? new SteamCompatibilityToolDiscovery (installation_type, Globals.IS_FLATPAK);
        }

        public override SteamRestartTarget? get_steam_restart_target () {
            if (directory == "")
                return null;
            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                return SteamRestartTarget.for_native (directory, "Steam", "steam.desktop");
            case Launcher.InstallationTypes.FLATPAK:
                return SteamRestartTarget.for_flatpak (directory);
            case Launcher.InstallationTypes.SNAP:
                return SteamRestartTarget.for_snap (directory);
            default:
                return null;
            }
        }

        public static bool is_steam_linux_runtime (string display_title, string internal_title = "") {
            return display_title.down ().contains ("steam linux runtime")
                   || internal_title.down ().contains ("steam_linux_runtime")
                   || internal_title.down ().contains ("steamlinuxruntime");
        }

        public static CompatibilityToolRuntimeKind get_compatibility_tool_runtime_kind (CompatibilityTool? tool) {
            if (tool == null)
                return CompatibilityToolRuntimeKind.UNKNOWN;
            if (tool.runtime_kind != CompatibilityToolRuntimeKind.UNKNOWN)
                return tool.runtime_kind;
            if (tool.internal_title == "Default")
                return CompatibilityToolRuntimeKind.PROTON;
            if (is_steam_linux_runtime (tool.display_title, tool.internal_title))
                return CompatibilityToolRuntimeKind.NATIVE;
            return CompatibilityToolRuntimeKind.UNKNOWN;
        }

        public static bool is_game_steam_linux_runtime_compatible (Game game) {
            var steam_game = game as Games.Steam;
            return game.is_native || (steam_game != null && ((!) steam_game).is_non_steam);
        }

        public bool has_explicit_compatibility_tool_mapping (uint appid) {
            return compatibility_tool_hashtable.contains (appid);
        }

        public void update_game_compatibility_tool_mapping (uint appid, string compatibility_tool) {
            if (compatibility_tool == "Default")
                compatibility_tool_hashtable.remove (appid);
            else
                compatibility_tool_hashtable.set (appid, compatibility_tool);
        }

        public override List<string> get_managed_tool_directories (Group group) {
            var directories = new List<string> ();
            directories.append (get_primary_managed_tool_directory (group));
            return directories;
        }

        public override string get_primary_managed_tool_directory (Group group) {
            return get_managed_compatibility_tools_root ();
        }

        private string get_managed_compatibility_tools_root () {
            if (installation_type == Launcher.InstallationTypes.SYSTEM
                && Filename.canonicalize (directory, null) == "/usr/share/steam") {
                var host_data_home = Environment.get_variable ("HOST_XDG_DATA_HOME");
                if (host_data_home == null || host_data_home == "") {
                    host_data_home = Globals.IS_FLATPAK
                        ? Path.build_filename (Environment.get_home_dir (), ".local", "share")
                        : Environment.get_user_data_dir ();
                }
                return Path.build_filename (
                    (!) host_data_home, "Steam", "compatibilitytools.d"
                );
            }
            return Path.build_filename (directory, "compatibilitytools.d");
        }

        public SteamProfile? get_steam_profile_by_id (string steam_id) {
            foreach (var profile in profiles)
                if (profile.steam_id == steam_id)
                    return profile;
            return null;
        }

        public async void switch_profile (SteamProfile profile) {
            if (this.profile != null) {
                foreach (var non_steam_game in this.profile.non_steam_games) {
                    games.remove (non_steam_game);
                }
            }

            foreach (var game in (List<Games.Steam>) games) {
                var launch_options = profile.launch_options_hashtable.get (game.appid);
                game.launch_options = launch_options;
            }

            foreach (var non_steam_game in profile.non_steam_games) {
                games.append (non_steam_game);
            }

            this.profile = profile;
        }

        public override int get_compatibility_tool_usage_count (string compatibility_tool_name) {
            return get_compatibility_tool_usage_games (compatibility_tool_name).size;
        }

        public Gee.List<Game> get_compatibility_tool_usage_games (string compatibility_tool_name) {
            var usage_games = new Gee.ArrayList<Game> ();
            bool is_default_tool = (compatibility_tool_name == default_compatibility_tool);

            foreach (var game in games) {
                if (uses_compatibility_tool (game, compatibility_tool_name, is_default_tool))
                    usage_games.add (game);
            }

            foreach (var profile in profiles) {
                if (profile == this.profile)
                    continue;

                foreach (var game in profile.non_steam_games) {
                    if (uses_compatibility_tool (game, compatibility_tool_name, is_default_tool))
                        usage_games.add (game);
                }
            }

            return usage_games;
        }

        private bool uses_compatibility_tool (
            Game game,
            string compatibility_tool_name,
            bool is_default_tool
        ) {
            return !game.is_native && (
                game.compatibility_tool == compatibility_tool_name ||
                (is_default_tool && game.compatibility_tool == "Default")
            );
        }

        public override async bool load_game_library () {
            var current_generation = ++game_library_generation;
            games = new List<Game> ();

            compatibility_tools.clear ();
            compatibility_tool_discovery.clear ();

            var name_regex = /\"name\"\s+\"([^\"]+)\"/;
            var dir_regex = /\"installdir\"\s+\"([^\"]+)\"/;

            var excluded_appids = new Gee.HashSet<string> ();
            excluded_appids.add_all_array (new string[] {
                "2230260", "1826330", "1161040", "1070560", "1628350", "228980", "4183110", "3086180", "250820"
            });

            var compatibility_tool_hashtable_loaded = yield load_compatibility_tool_hashtable ();
            if (!compatibility_tool_hashtable_loaded)
            return false;

            var default_compatibility_tool = compatibility_tool_hashtable.get (0);
            if (default_compatibility_tool != null)
            this.default_compatibility_tool = default_compatibility_tool;

            var libraryfolder_content = yield Utils.Filesystem.get_file_content_async ("%s/steamapps/libraryfolders.vdf".printf (directory));

            var libraryfolder_document = Utils.VDF.VdfParser.parse_document (libraryfolder_content);
            if (libraryfolder_document == null)
                return false;

            var libraryfolders = libraryfolder_document.root.get_child ("libraryfolders");
            if (libraryfolders == null)
                return false;

            foreach (var libraryfolder in libraryfolders.children) {
                int libraryfolder_id;
                if (!int.try_parse (libraryfolder.key, out libraryfolder_id))
                    continue;

                var path = libraryfolder.get_child ("path");
                var apps = libraryfolder.get_child ("apps");
                if (path == null || path.value == null || apps == null)
                    continue;

                foreach (var app in apps.children) {
                    uint id = 0;
                    var id_valid = uint.try_parse (app.key, out id);
                    if (!id_valid)
                    continue;

                    var current_libraryfolder_id = libraryfolder_id;
                    var current_libraryfolder_path = path.value;
                    var current_appid = app.key;
                    var current_steamapps_path = "%s/steamapps".printf (path.value);
                    var current_manifest_path = "";
                    var current_manifest_content = "";
                    var current_name = "";
                    var current_installdir = "";

                    current_manifest_path = "%s/appmanifest_%s.acf".printf (current_steamapps_path, current_appid);
                    if (!FileUtils.test (current_manifest_path, FileTest.IS_REGULAR))
                    continue;
                    current_manifest_content = Utils.Filesystem.get_file_content (current_manifest_path);

                    MatchInfo name_match;
                    if (!name_regex.match (current_manifest_content, 0, out name_match))
                    continue;
                    current_name = name_match.fetch (1);

                    MatchInfo dir_match;
                    if (!dir_regex.match (current_manifest_content, 0, out dir_match))
                    continue;
                    current_installdir = dir_match.fetch (1);

                    string steam_tool_internal_title;
                    CompatibilityToolRuntimeKind steam_tool_runtime_kind;
                    if (SteamCompatibilityToolDiscovery.try_get_steam_library_tool_identity (
                            id, out steam_tool_internal_title, out steam_tool_runtime_kind
                        )) {
                        compatibility_tool_discovery.add_steam_library_app (
                            "%s/common/%s".printf (current_steamapps_path, current_installdir),
                            id, steam_tool_internal_title, current_name, steam_tool_runtime_kind
                        );
                        continue;
                    }

                    if (excluded_appids.contains (current_appid)) {
                        continue;
                    }

                    var compatibility_tool_path = "%s/common/%s".printf (current_steamapps_path, current_installdir);
                    var has_proton_launcher = FileUtils.test (
                        Path.build_filename (compatibility_tool_path, "proton"),
                        FileTest.IS_REGULAR
                    );

                    if (has_proton_launcher || is_steam_linux_runtime (current_name)) {
                        debug ("Ignoring unrecognized Steam compatibility-tool app %s (%s)",
                            current_appid, current_name);
                        continue;
                    }

                    if (!FileUtils.test ("%s/common/%s".printf (current_steamapps_path, current_installdir), FileTest.IS_DIR))
                    continue;

                    var game = new Games.Steam (id, current_name, current_installdir, current_libraryfolder_id, current_libraryfolder_path, this);

                    var compatibility_tool = compatibility_tool_hashtable.get (game.appid);
                    if (compatibility_tool == null)
                    compatibility_tool = "Default";
                    game.compatibility_tool = compatibility_tool;

                    games.append (game);
                }
            }

            load_discovered_compatibility_tools ();

            schedule_awacy_enrichment (current_generation);

            return true;
        }

        private void schedule_awacy_enrichment (uint generation) {
            Idle.add (() => {
                enrich_games_with_awacy.begin (generation);
                return Source.REMOVE;
            });
        }

        private async void enrich_games_with_awacy (uint generation) {
            var awacy_games = yield awacy_game_catalog.get_games ();
            if (generation != game_library_generation)
                return;

            foreach (var base_game in games) {
                var game = base_game as Games.Steam;
                if (game == null || ((!) game).is_non_steam)
                    continue;

                if (awacy_games.has_key (((!) game).appid)) {
                    var awacy_game = awacy_games.get (((!) game).appid);
                    if (awacy_game != null) {
                        ((!) game).awacy_name = ((!) awacy_game).name;
                        ((!) game).awacy_status = ((!) awacy_game).status;
                    }
                }
                ((!) game).awacy_lookup_complete = true;
            }
        }

        public void refresh_compatibility_tools () {
            compatibility_tool_discovery.clear ();
            load_discovered_compatibility_tools ();
        }

        private void load_discovered_compatibility_tools () {
            compatibility_tool_discovery.discover_launcher_roots (
                get_managed_compatibility_tools_root ()
            );
            compatibility_tools.clear ();
            foreach (var compatibility_tool in compatibility_tool_discovery.get_snapshot ()) {
                compatibility_tool.sort_priority = get_compatibility_tool_sort_priority (compatibility_tool);
                compatibility_tools.add (compatibility_tool);
            }
            add_unavailable_mappings ();
            sort_compatibility_tools ();
        }

        private void add_unavailable_mappings () {
            if (compatibility_tool_hashtable == null)
                return;
            foreach (var internal_title in compatibility_tool_hashtable.get_values ()) {
                if (internal_title == null || internal_title == "Default"
                    || find_compatibility_tool (internal_title) != null)
                    continue;
                var unavailable = new CompatibilityTool (
                    _("%s (Unavailable)").printf (internal_title), internal_title
                );
                unavailable.is_available = false;
                unavailable.is_assignable = false;
                unavailable.sort_priority = 900;
                compatibility_tools.add (unavailable);
            }
        }

        private void add_compatibility_tool_if_missing (CompatibilityTool compatibility_tool) {
            foreach (var existing_runner in compatibility_tools) {
                if (existing_runner.path == compatibility_tool.path || existing_runner.internal_title == compatibility_tool.internal_title) {
                    return;
                }
            }

            compatibility_tool.sort_priority = get_compatibility_tool_sort_priority (compatibility_tool);
            compatibility_tools.add (compatibility_tool);
        }

        public void register_compatibility_tool (CompatibilityTool compatibility_tool) {
            add_compatibility_tool_if_missing (compatibility_tool);
            sort_compatibility_tools ();
        }

        public CompatibilityTool? find_compatibility_tool (string internal_title) {
            foreach (var tool in compatibility_tools) {
                if (tool.internal_title == internal_title)
                    return tool;
            }
            return null;
        }

        public Gee.List<CompatibilityTool> get_assignable_compatibility_tools () {
            var tools = new Gee.ArrayList<CompatibilityTool> ();
            foreach (var tool in compatibility_tools) {
                if (tool.is_assignable && tool.is_available)
                    tools.add (tool);
            }
            return tools;
        }

        public bool can_assign_compatibility_tool (string internal_title) {
            if (internal_title == "Default")
                return true;
            var tool = find_compatibility_tool (internal_title);
            if (tool == null || !((!) tool).is_assignable || !((!) tool).is_available)
                return false;
            return !((!) tool).externally_managed
                || compatibility_tool_discovery.remains_available ((!) tool);
        }

        public bool external_compatibility_tool_remains_available (string internal_title) {
            var tool = find_compatibility_tool (internal_title);
            if (tool == null || !((!) tool).externally_managed)
                return true;
            return ((!) tool).is_assignable && ((!) tool).is_available
                && compatibility_tool_discovery.remains_available ((!) tool);
        }

        /* Steam persists "Default" as an alias for CompatToolMapping app ID 0.
         * Resolve that alias at the launcher boundary so consumers which need
         * a concrete installation (feature probes and future compatibility
         * checks) do not guess from its display name or list position. */
        public CompatibilityTool? resolve_effective_compatibility_tool (string selected_internal_title) {
            var effective_internal_title = selected_internal_title;
            if (effective_internal_title == "Default")
                effective_internal_title = default_compatibility_tool;

            if (effective_internal_title == null
                || effective_internal_title.strip () == ""
                || effective_internal_title == "Default")
                return null;

            return find_compatibility_tool (effective_internal_title);
        }

        public string? resolve_effective_proton_executable (string selected_internal_title) {
            var tool = resolve_effective_compatibility_tool (selected_internal_title);
            if (tool == null || ((!) tool).path.strip () == "")
                return null;

            var inspection_proton_path = Path.build_filename (((!) tool).inspection_path, "proton");
            if (!FileUtils.test (inspection_proton_path, FileTest.IS_REGULAR)
                || !FileUtils.test (inspection_proton_path, FileTest.IS_EXECUTABLE))
                return null;

            return Path.build_filename (((!) tool).path, "proton");
        }

        public override void register_compatibility_tool_from_path (string tool_path) {
            register_compatibility_tool (Utils.VDF.CompatibilityToolLoader.from_path (tool_path));
        }

        public override void unregister_compatibility_tool_by_path (string tool_path) {
            var tool = compatibility_tools.first_match ((tool) => {
                return tool.path == tool_path;
            });

            if (tool == null) {
                return;
            }

            compatibility_tools.remove (tool);
            sort_compatibility_tools ();
        }

        private void sort_compatibility_tools () {
            compatibility_tools.sort ((a, b) => {
                if (a.sort_priority != b.sort_priority)
                    return a.sort_priority - b.sort_priority;

                int a_major = 0;
                int a_minor = 0;
                int b_major = 0;
                int b_minor = 0;

                var has_a_proton_version = try_parse_any_proton_version (a.display_title, out a_major, out a_minor);
                var has_b_proton_version = try_parse_any_proton_version (b.display_title, out b_major, out b_minor);

                if (has_a_proton_version && has_b_proton_version) {
                    if (a_major != b_major)
                        return b_major - a_major;

                    if (a_minor != b_minor)
                        return b_minor - a_minor;
                }

                return strcmp (a.display_title.down (), b.display_title.down ());
            });
        }

        private int get_compatibility_tool_sort_priority (CompatibilityTool tool) {
            var title = tool.display_title.down ();
            var internal_title = tool.internal_title.down ();

            if (internal_title == "proton_experimental" || title.contains ("proton experimental")) {
                return 100;
            }

            if (internal_title == "proton_hotfix" || title.contains ("proton hotfix")) {
                return 150;
            }

            int major = 0;
            int minor = 0;
            if (try_parse_proton_version (tool.display_title, out major, out minor)) {
                return 200;
            }

            if (title.contains ("proton") || internal_title.contains ("proton")) {
                return 300;
            }

            if (is_steam_linux_runtime (tool.display_title, tool.internal_title)) {
                return 400;
            }

            return 500;
        }

        private bool try_parse_proton_version (string title, out int major, out int minor) {
            major = 0;
            minor = 0;

            try {
                var regex = new GLib.Regex ("""(?ix)^\s*proton\s+ (\d+) (?:\. (\d+))?""");
                GLib.MatchInfo match;
                if (!regex.match (title, 0, out match)) {
                    return false;
                }

                int.try_parse (match.fetch (1), out major);

                var minor_text = match.fetch (2);
                if (minor_text != null && minor_text != "") {
                    int.try_parse (minor_text, out minor);
                }

                return true;
            } catch (GLib.RegexError e) {
                return false;
            }
        }

        private bool try_parse_any_proton_version (string title, out int major, out int minor) {
            major = 0;
            minor = 0;

            try {
                // Matches custom names like GE-Proton11-1, proton-cachyos-11.0, etc.
                var regex = new GLib.Regex ("""(?ix)proton[^0-9]* (\d+) (?:[\._-] (\d+))?""");
                GLib.MatchInfo match;
                if (!regex.match (title, 0, out match)) {
                    return false;
                }

                int.try_parse (match.fetch (1), out major);

                var minor_text = match.fetch (2);
                if (minor_text != null && minor_text != "") {
                    int.try_parse (minor_text, out minor);
                }

                return true;
            } catch (GLib.RegexError e) {
                return false;
            }
        }

        async bool load_compatibility_tool_hashtable () {
            compatibility_tool_hashtable = new HashTable<uint, string> (null, null);

            var config_content = yield Utils.Filesystem.get_file_content_async ("%s/config/config.vdf".printf (directory));
            var document = Utils.VDF.VdfParser.parse_document (config_content);
            if (document == null)
                return false;

            var install_config_store = document.root.get_child ("InstallConfigStore");
            var software = install_config_store != null ? install_config_store.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null;
            var steam = valve != null ? valve.get_child ("Steam") : null;
            var mapping = steam != null ? steam.get_child ("CompatToolMapping") : null;
            if (mapping == null) {
                compatibility_tool_hashtable.set (0, "proton_experimental");
                var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
                if (configuration != null)
                    configuration.overlay_launcher_effective_state (this);
                return true;
            }

            foreach (var mapping_entry in mapping.children) {
                uint appid;
                if (!uint.try_parse (mapping_entry.key, out appid))
                    continue;

                var name = mapping_entry.get_child ("name");
                if (name == null || name.value == null)
                    continue;

                compatibility_tool_hashtable.set (appid, name.value);
            }

            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            if (configuration != null)
                configuration.overlay_launcher_effective_state (this);

            return true;
        }

        public bool change_default_compatibility_tool (string compatibility_tool) {
            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            if (configuration == null) {
                warning ("Steam default compatibility change rejected because SteamConfigurationService is not configured.");
                return false;
            }

            var outcome = ((!) configuration).change_default_compatibility_tool (this, compatibility_tool);
            if (!outcome.accepted)
                return false;
            this.default_compatibility_tool = compatibility_tool;
            return true;
        }
    }
}
