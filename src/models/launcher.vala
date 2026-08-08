namespace ProtonPlus.Models {
    using ProtonPlus.Models.Providers;
    public class Launcher : Object {
        public string family_id { get; private set; }
        public string instance_id { get; private set; }
        // Launcher IDs identify the UI selection. Tool target IDs identify the
        // physical storage location and may intentionally be shared.
        public string tool_target_family_id { get; private set; }
        public string tool_target_id { get; private set; }
        public string title;
        public string icon_path;
        public string directory;
        public bool installed;
        public bool has_library_support;
        public List<Game> games;
        public Gee.LinkedList<CompatibilityTool> compatibility_tools;

        public Group[] groups;

        public InstallationTypes installation_type;


        public enum InstallationTypes {
            SYSTEM,
            FLATPAK,
            SNAP
        }

        public Launcher (
            string title,
            InstallationTypes installation_type,
            string icon_path,
            string[] directories,
            string family_id = "unknown",
            string[]? detection_markers = null,
            string? tool_target_directory = null,
            string? tool_target_family_id = null,
            string? tool_target_id = null
        ) {
            this.family_id = family_id;
            this.instance_id = "%s-%s".printf (family_id, get_installation_type_id (installation_type));
            this.tool_target_family_id = tool_target_family_id ?? family_id;
            this.tool_target_id = tool_target_id ?? this.instance_id;
            this.title = title;
            this.installation_type = installation_type;
            this.icon_path = icon_path;
            this.directory = "";

            var installed = false;
            if (detection_markers != null) {
                foreach (var marker in detection_markers) {
                    if (!FileUtils.test (marker, FileTest.EXISTS))
                        continue;
                    installed = true;
                    break;
                }
            } else {
                foreach (var current_path in directories) {
                    if (!FileUtils.test (current_path, FileTest.IS_DIR))
                        continue;

                    var steam_installation_valid = !(this is Launchers.Steam)
                                                   || (FileUtils.test (Path.build_filename (current_path, "steamclient.dll"), FileTest.IS_REGULAR)
                                                       && FileUtils.test (Path.build_filename (current_path, "steamclient64.dll"), FileTest.IS_REGULAR));
                    if (!steam_installation_valid)
                        continue;

                    this.directory = current_path;
                    installed = true;
                    break;
                }
            }

            if (tool_target_directory != null)
                this.directory = tool_target_directory;

            compatibility_tools = new Gee.LinkedList<CompatibilityTool> ();

            this.installed = installed;
        }

        public string get_installation_type_title () {
            switch (installation_type) {
            case InstallationTypes.SYSTEM:
                return "System";
            case InstallationTypes.FLATPAK:
                return "Flatpak";
            case InstallationTypes.SNAP:
                return "Snap";
            default:
                return "Invalid type";
            }
        }

        private static string get_installation_type_id (InstallationTypes installation_type) {
            switch (installation_type) {
            case InstallationTypes.SYSTEM:
                return "system";
            case InstallationTypes.FLATPAK:
                return "flatpak";
            case InstallationTypes.SNAP:
                return "snap";
            default:
                return "unknown";
            }
        }

        public virtual async bool load_game_library () {
            return true;
        }

        /*
         * A launcher UI identity is not necessarily a Steam installation
         * identity.  Consumers that need to observe a Steam session use this
         * narrow, read-only capability instead of inspecting launcher types.
         */
        public virtual SteamRestartTarget? get_steam_restart_target () {
            return null;
        }

        public static async bool get_all (out Gee.LinkedList<Launcher> launchers) {
            var _launchers = new Gee.LinkedList<Launcher> ();
            var definitions = new ProviderRegistry ();

            Launcher[] candidates = {
                new Launchers.Steam (InstallationTypes.SYSTEM),
                new Launchers.Steam (InstallationTypes.FLATPAK),
                new Launchers.Steam (InstallationTypes.SNAP),
                new Launchers.FaugusLauncher (InstallationTypes.SYSTEM),
                new Launchers.FaugusLauncher (InstallationTypes.FLATPAK),
                new Launchers.Lutris (InstallationTypes.SYSTEM),
                new Launchers.Lutris (InstallationTypes.FLATPAK),
                new Launchers.Bottles (InstallationTypes.SYSTEM),
                new Launchers.Bottles (InstallationTypes.FLATPAK),
                new Launchers.HeroicGamesLauncher (InstallationTypes.SYSTEM),
                new Launchers.HeroicGamesLauncher (InstallationTypes.FLATPAK),
                new Launchers.WineZGUI (InstallationTypes.SYSTEM),
                new Launchers.WineZGUI (InstallationTypes.FLATPAK)
            };

            foreach (var launcher in candidates) {
                if (launcher.installed) {
                    _launchers.add (launcher);
                }
            }

            launchers = (owned) _launchers;

            if (launchers == null || launchers.size == 0)
                return true;

            var initialized = yield initialize_launchers (launchers, definitions);

            if (!initialized)
                return false;

            return true;
        }

        public static async bool initialize_launchers (Gee.LinkedList<Launcher> launchers, ProviderRegistry definitions) {
            foreach (var launcher in launchers) {
                var categories = get_categories_for_launcher (launcher);
                if (categories == null)
                    return false;

                var launcher_groups = new Gee.ArrayList<Group> ();

                foreach (var category in categories) {
                    var group_title = get_group_title (category);
                    var group_description = get_group_description (category);
                    var group_directory = get_group_directory (launcher, category);

                    if (group_directory == null)
                        return false;

                    if (!yield launcher.ensure_group_directory (group_directory))
                        return false;

                    var app_group = new Group (
                                               group_title,
                                               Utils.safe_translate (group_description),
                                               group_directory,
                                               launcher,
                                               get_group_id (category)
                    );
                    app_group.tools = new Gee.LinkedList<Tool> ();

                    foreach (var definition in definitions.get (category)) {
                        if (!launcher.supports_provider_definition (definition))
                            continue;
                        var tool = ProviderCatalog.create_tool (definition, app_group);
                        if (tool != null) {
                            app_group.tools.add (tool);
                        }
                    }

                    if (launcher is Launchers.Steam && category == Category.PROTON) {
                        app_group.tools.add (new Tools.SteamTinkerLaunch (app_group));
                    }

                    launcher_groups.add (app_group);
                }

                launcher.groups = launcher_groups.to_array ();

                if (launcher.installed) {
                    var success = yield launcher.setup_profile_library_for_test ();

                    if (!success)
                        return false;
                }
            }

            return true;
        }

        private static Category[]? get_categories_for_launcher (Launcher launcher) {
            if (launcher is Launchers.Steam || launcher is Launchers.FaugusLauncher)
                return { Category.PROTON };

            if (launcher is Launchers.Lutris)
                return { Category.PROTON, Category.WINE, Category.DXVK, Category.VKD3D };

            if (launcher is Launchers.HeroicGamesLauncher)
                return { Category.PROTON, Category.WINE };

            if (launcher is Launchers.Bottles)
                return { Category.PROTON, Category.WINE, Category.DXVK };

            if (launcher is Launchers.WineZGUI)
                return { Category.WINE };

            return null;
        }

        private static string get_group_title (Category category) {
            switch (category) {
            case Category.DXVK:
                return "DXVK";
            case Category.VKD3D:
                return "VKD3D";
            case Category.PROTON:
                return "Proton";
            case Category.WINE:
                return "Wine";
            }

            return "";
        }

        private static string get_group_id (Category category) {
            switch (category) {
            case Category.DXVK:
                return "dxvk";
            case Category.VKD3D:
                return "vkd3d";
            case Category.PROTON:
                return "proton";
            case Category.WINE:
                return "wine";
            }

            return "unknown";
        }

        private static string get_group_description (Category category) {
            switch (category) {
            case Category.DXVK:
                return "Vulkan-based implementation of Direct3D 8, 9, 10 and 11 for Linux/Wine.";
            case Category.VKD3D:
                return "Variant of Wine's VKD3D which aims to implement the full Direct3D 12 API on top of Vulkan.";
            case Category.PROTON:
                return "Compatibility tools by Valve for running Windows software on Linux.";
            case Category.WINE:
                return "Compatibility tools for running Windows software on Linux.";
            }

            return "";
        }

        private static string? get_group_directory (Launcher launcher, Category category) {
            if ((launcher is Launchers.Steam || launcher is Launchers.FaugusLauncher) && category == Category.PROTON)
                return "/compatibilitytools.d";

            if (launcher is Launchers.Lutris) {
                switch (category) {
                case Category.PROTON:
                case Category.WINE:
                    return "/runners/wine";
                case Category.DXVK:
                    return "/runtime/dxvk";
                case Category.VKD3D:
                    return "/runtime/vkd3d";
                }
            }

            if (launcher is Launchers.HeroicGamesLauncher) {
                switch (category) {
                case Category.PROTON:
                    return "/tools/proton";
                case Category.WINE:
                    return "/tools/wine";
                default:
                    return null;
                }
            }

            if (launcher is Launchers.Bottles) {
                switch (category) {
                case Category.PROTON:
                case Category.WINE:
                    return "/runners";
                case Category.DXVK:
                    return "/dxvk";
                default:
                    return null;
                }
            }

            if (launcher is Launchers.WineZGUI && category == Category.WINE)
                return "/Runners";

            return null;
        }

        public virtual async bool setup_profile_library_for_test () {
            var games_loaded = yield this.load_game_library ();

            if (!games_loaded)
                return false;

            if (this is Launchers.Steam) {
                var steam_launcher = this as Launchers.Steam;
                steam_launcher.profiles = SteamProfile.get_profiles (steam_launcher);

                foreach (var profile in steam_launcher.profiles) {
                    yield profile.load_extra_data ();
                }

                var selected_profile = steam_launcher.get_steam_profile_by_id (Globals.SETTINGS.get_string ("steam-selected-profile-id"));

                if (selected_profile != null || steam_launcher.profiles.length () > 0)
                    yield steam_launcher.switch_profile (selected_profile != null ? selected_profile : steam_launcher.profiles.nth_data (0));
                else
                    return false;
            }
            return true;
        }

        public virtual List<string> get_tool_directories (Group group) {
            var directories = new List<string> ();
            directories.append (this.directory + group.directory);
            return directories;
        }

        public virtual async bool ensure_group_directory (string group_directory) {
            return true;
        }

        public virtual bool supports_provider_definition (ProviderDefinition definition) {
            return true;
        }

        public virtual int get_compatibility_tool_usage_count (string compatibility_tool_name) {
            return 0;
        }

        public virtual void register_compatibility_tool_from_path (string tool_path) {}

        public virtual void unregister_compatibility_tool_by_path (string tool_path) {}
    }
}
