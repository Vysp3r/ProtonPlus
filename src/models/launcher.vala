namespace ProtonPlus.Models {
    using ProtonPlus.Models.Launchers.Runners;
    public class Launcher : Object {
        public string title;
        public string icon_path;
        public string directory;
        public bool installed;
        public bool has_library_support;
        public List<Game> games;
        public Gee.LinkedList<Tools.Simple> compatibility_tools;

        public Group[] groups;

        public InstallationTypes installation_type;


        public enum InstallationTypes {
            SYSTEM,
            FLATPAK,
            SNAP
        }

        public Launcher (string title, InstallationTypes installation_type, string icon_path, string[] directories) {
            this.title = title;
            this.installation_type = installation_type;
            this.icon_path = icon_path;
            this.directory = "";

            foreach (var current_path in directories) {
                if (FileUtils.test (current_path, FileTest.IS_DIR)) {
                    if (!(this is Launchers.Steam) || (FileUtils.test (current_path + "/steamclient.dll", FileTest.IS_REGULAR) && FileUtils.test (current_path + "/steamclient64.dll", FileTest.IS_REGULAR))) {
                        this.directory = current_path;
                        break;
                    }
                }
            }

            compatibility_tools = new Gee.LinkedList<Tools.Simple> ();

            installed = directory.length > 0;
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

        public virtual async bool load_game_library () {
            return true;
        }

        public static async bool get_all (out Gee.LinkedList<Launcher> launchers) {
            var _launchers = new Gee.LinkedList<Launcher> ();
            var runners = new Runners ();

            Launcher[] candidates = {
                new Launchers.Steam (InstallationTypes.SYSTEM),
                new Launchers.Steam (InstallationTypes.FLATPAK),
                new Launchers.Steam (InstallationTypes.SNAP),
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

            var initialized = yield initialize_launchers (launchers, runners);

            if (!initialized)
                return false;

            return true;
        }

        public static async bool initialize_launchers (Gee.LinkedList<Launcher> launchers, Runners runners) {
            foreach (var launcher in launchers) {
                var runner_types = get_runner_types_for_launcher (launcher);
                if (runner_types == null)
                    return false;

                var launcher_groups = new Gee.ArrayList<Group> ();

                foreach (var runner_type in runner_types) {
                    var group_title = get_group_title (runner_type);
                    var group_description = get_group_description (runner_type);
                    var group_directory = get_group_directory (launcher, runner_type);

                    if (group_directory == null)
                        return false;

                    var app_group = new Group (
                                               group_title,
                                               Utils.safe_translate (group_description),
                                               group_directory,
                                               launcher
                    );
                    app_group.tools = new Gee.LinkedList<Tool> ();

                    foreach (var runner_data in get_runners_for_type (runners, runner_type)) {
                        var tool = runner_data.create_tool (app_group);
                        if (tool != null) {
                            app_group.tools.add (tool);
                        }
                    }

                    if (launcher is Launchers.Steam && runner_type == RunnerType.Proton) {
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

        private static Gee.ArrayList<IRunner> get_runners_for_type (Runners runners, RunnerType runner_type) {
            return runners.getRunners (runner_type);
        }

        private static RunnerType[]? get_runner_types_for_launcher (Launcher launcher) {
            if (launcher is Launchers.Steam)
                return { RunnerType.Proton };

            if (launcher is Launchers.Lutris)
                return { RunnerType.Proton, RunnerType.Wine, RunnerType.DXVK, RunnerType.VKD3D };

            if (launcher is Launchers.HeroicGamesLauncher)
                return { RunnerType.Proton, RunnerType.Wine };

            if (launcher is Launchers.Bottles)
                return { RunnerType.Proton, RunnerType.Wine, RunnerType.DXVK };

            if (launcher is Launchers.WineZGUI)
                return { RunnerType.Wine };

            return null;
        }

        private static string get_group_title (RunnerType runner_type) {
            switch (runner_type) {
            case RunnerType.DXVK:
                return "DXVK";
            case RunnerType.VKD3D:
                return "VKD3D";
            case RunnerType.Proton:
                return "Proton";
            case RunnerType.Wine:
                return "Wine";
            }

            return "";
        }

        private static string get_group_description (RunnerType runner_type) {
            switch (runner_type) {
            case RunnerType.DXVK:
                return "Vulkan-based implementation of Direct3D 8, 9, 10 and 11 for Linux/Wine.";
            case RunnerType.VKD3D:
                return "Variant of Wine's VKD3D which aims to implement the full Direct3D 12 API on top of Vulkan.";
            case RunnerType.Proton:
                return "Compatibility tools by Valve for running Windows software on Linux.";
            case RunnerType.Wine:
                return "Compatibility tools for running Windows software on Linux.";
            }

            return "";
        }

        private static string? get_group_directory (Launcher launcher, RunnerType runner_type) {
            if (launcher is Launchers.Steam && runner_type == RunnerType.Proton)
                return "/compatibilitytools.d";

            if (launcher is Launchers.Lutris) {
                switch (runner_type) {
                case RunnerType.Proton:
                case RunnerType.Wine:
                    return "/runners/wine";
                case RunnerType.DXVK:
                    return "/runtime/dxvk";
                case RunnerType.VKD3D:
                    return "/runtime/vkd3d";
                }
            }

            if (launcher is Launchers.HeroicGamesLauncher) {
                switch (runner_type) {
                case RunnerType.Proton:
                    return "/tools/proton";
                case RunnerType.Wine:
                    return "/tools/wine";
                default:
                    return null;
                }
            }

            if (launcher is Launchers.Bottles) {
                switch (runner_type) {
                case RunnerType.Proton:
                case RunnerType.Wine:
                    return "/runners";
                case RunnerType.DXVK:
                    return "/dxvk";
                default:
                    return null;
                }
            }

            if (launcher is Launchers.WineZGUI && runner_type == RunnerType.Wine)
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
            }
            return true;
        }

        public virtual int get_compatibility_tool_usage_count (string compatibility_tool_name) {
            return 0;
        }
    }
}
