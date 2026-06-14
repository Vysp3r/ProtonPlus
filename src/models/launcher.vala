namespace ProtonPlus.Models {
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

            var initialized = yield initialize_launchers (launchers);

            if (!initialized)
                return false;

            return true;
        }

        public static async bool initialize_launchers (Gee.LinkedList<Launcher> launchers, string? custom_json_path = null) {
            string json_content = "";

            if (custom_json_path != null) {
                try {
                    uint8[] raw_data;
                    FileUtils.get_data (custom_json_path, out raw_data);
                    json_content = (string) raw_data;
                } catch (FileError e) {
                    stderr.printf ("Error while loading JSON: %s\n", e.message);
                    return false;
                }
            } else {
                json_content = Utils.Filesystem.get_file_content ("resource://com/vysp3r/ProtonPlus/runners.json", true);
            }

            if (json_content == "")
                return false;

            var root_data = ProtonPlus.Models.Internal.Data.Runner.Parser.parse_runners_json (json_content);
            if (root_data == null)
                return false;

            var compat_layers_map = new Gee.HashMap<string, ProtonPlus.Models.Internal.Data.Runner.CompatLayerGroup> ();
            foreach (var layer in root_data.compat_layers) {
                compat_layers_map.set (layer.title, layer);
            }

            var launchers_map = new Gee.HashMap<string, ProtonPlus.Models.Internal.Data.Runner.Launcher> ();
            foreach (var l in root_data.launchers) {
                launchers_map.set (l.title, l);
            }

            foreach (var launcher in launchers) {
                var json_launcher = launchers_map.get (launcher.title);
                if (json_launcher == null)
                    return false;

                var launcher_groups = new Gee.ArrayList<Group> ();

                foreach (var launcher_cl in json_launcher.compat_layers) {
                    var global_group_data = compat_layers_map.get (launcher_cl.title);
                    if (global_group_data == null)
                        return false;

                    var app_group = new Group (
                                               launcher_cl.title,
                                               Utils.safe_translate (global_group_data.description),
                                               launcher_cl.directory,
                                               launcher
                    );
                    app_group.tools = new Gee.LinkedList<Tool> ();

                    foreach (var runner_data in global_group_data.runners) {
                        var tool = create_runner_from_model (runner_data, app_group);
                        if (tool != null) {
                            app_group.tools.add (tool);
                        }
                    }

                    if (launcher.title == "Steam") {
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

        private static Tools.Basic? create_runner_from_model (ProtonPlus.Models.Internal.Data.Runner.Runner runner_data, Group group) {
            string? target_format = null;
            foreach (var format in runner_data.directory_name_formats) {
                if (format.launcher == group.launcher.title) {
                    target_format = format.directory_name_format;
                    break;
                }
            }

            if (target_format == null) {
                foreach (var format in runner_data.directory_name_formats) {
                    if (format.launcher == "default") {
                        target_format = format.directory_name_format;
                        break;
                    }
                }
            }

            if (target_format == null)
                return null;

            Tools.Basic ? runner = null;

            switch (runner_data.runner_type) {
            case "github" :
                var github = new Tools.GitHub ();
                if (runner_data.request_asset_exclude != null)github.request_asset_exclude = runner_data.request_asset_exclude.to_array ();
                if (runner_data.request_asset_filter != null)github.request_asset_filter = runner_data.request_asset_filter.to_array ();
                runner = github;
                break;
            case "github-action" :
                var github_action = new Tools.GitHubAction ();
                github_action.url_template = runner_data.url_template;
                runner = github_action;
                break;
            case "gitlab":
                var gitlab = new Tools.GitLab ();
                if (runner_data.request_asset_exclude != null)gitlab.request_asset_exclude = runner_data.request_asset_exclude.to_array ();
                runner = gitlab;
                break;
            case "forgejo":
                runner = new Tools.Forgejo ();
                break;
            default:
                warning ("Unknow type of runner: %s", runner_data.runner_type);
                break;
            }

            if (runner != null) {
                runner.title = runner_data.title;
                runner.description = Utils.safe_translate (runner_data.description);
                runner.endpoint = runner_data.endpoint;
                runner.asset_position = runner_data.asset_position;
                runner.asset_position_time_condition = runner_data.asset_position_time_condition;
                runner.directory_name_format = target_format;
                runner.has_latest_support = runner_data.support_latest;
                runner.group = group;
                runner.tag = runner_data.tag;
                runner.legacy = runner_data.legacy;

                runner.asset_position_hwcaps_condition = false;

                foreach (var rdv in runner_data.variants) {
                    Variant variant = new Variant (rdv.name, rdv.format, rdv.is_default, runner);
                    runner.variants.add (variant);
                }
            }

            return runner;
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