namespace ProtonPlus.Models.Games {
    public class Steam : Game {
        public uint appid { get; set; }
        public int library_folder_id { get; set; }
        public string library_folder_path { get; set; }
        public string awacy_name { get; set; }
        public string awacy_status { get; set; }
        public string launch_options { get; set; }
        public bool is_non_steam { get; set; }

        private bool? _is_native = null;
        public override bool is_native {
            get {
                if (_is_native == null)
                    _is_native = detect_native ();

                return _is_native;
            }
            set {
                _is_native = value;
            }
        }

        public Steam (
            uint appid,
            string name,
            string game_folder_name,
            int library_folder_id,
            string library_folder_path,
            Launchers.Steam launcher
        ) {
            base (
                name,
                Path.build_filename (library_folder_path, "steamapps", "common", game_folder_name),
                Path.build_filename (library_folder_path, "steamapps", "compatdata", appid.to_string ()),
                appid,
                launcher
            );

            this.appid = appid;
            this.library_folder_id = library_folder_id;
            this.library_folder_path = library_folder_path;
            this.launcher = launcher;
        }

        public Steam.non_steam (uint appid, string name, string launch_options, string compatibility_tool, Launchers.Steam launcher) {
            base (name, "", "%s/steamapps/compatdata/%u".printf (launcher.directory, appid), appid, launcher);

            this.appid = appid;
            this.launch_options = launch_options;
            this.compatibility_tool = compatibility_tool;
            this.is_non_steam = true;
        }

        private bool detect_native () {
            if (is_non_steam) {
                return true;
            }

            if (FileUtils.test (installdir, FileTest.IS_DIR)) {
                if (!FileUtils.test (prefixdir, FileTest.IS_DIR))
                    return true;

                try {
                    var dir = Dir.open (installdir, 0);
                    string? name;
                    while ((name = dir.read_name ()) != null) {
                        var path = Path.build_filename (installdir, name);
                        if (FileUtils.test (path, FileTest.IS_REGULAR) && FileUtils.test (path, FileTest.IS_EXECUTABLE)) {
                            var file = FileStream.open (path, "r");
                            if (file != null) {
                                uint8 magic[4];
                                if (file.read (magic) == 4) {
                                    if (magic[0] == 0x7f && magic[1] == 'E' && magic[2] == 'L' && magic[3] == 'F') {
                                        return true;
                                    }
                                }
                            }
                        }
                    }
                } catch (Error e) {
                    debug ("Could not inspect %s for native executables: %s", installdir, e.message);
                }
            }

            return false;
        }

        public override bool change_compatibility_tool (string compatibility_tool) {
            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            if (configuration != null) {
                var outcome = configuration.change_game_compatibility_tool (this, compatibility_tool);
                if (!outcome.accepted)
                    return false;
                this.compatibility_tool = compatibility_tool;
                if (is_non_steam)
                    _is_native = null;
                return true;
            }
            var config_path = "%s/config/config.vdf".printf (launcher.directory);
            var config_content = Utils.Filesystem.get_file_content (config_path);
            var document = Utils.VDF.VdfParser.parse_document (config_content);
            if (document == null)
                return false;

            var install_config_store = document.root.get_child ("InstallConfigStore");
            var software = install_config_store != null ? install_config_store.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null;
            var steam = valve != null ? valve.get_child ("Steam") : null;
            if (steam == null)
                return false;

            var mapping = steam.get_child ("CompatToolMapping");
            var app_mapping = mapping != null ? mapping.get_child (appid.to_string ()) : null;

            if (app_mapping != null) {
                if (compatibility_tool == _("Default")) {
                    config_content = document.remove_entry (app_mapping);
                } else {
                    var name = app_mapping.get_child ("name");
                    if (name == null || name.value == null)
                        return false;

                    config_content = document.replace_value (name, compatibility_tool);
                }
            } else if (compatibility_tool != _("Default")) {
                if (mapping == null) {
                    var steam_indent = document.indentation_of_closing_brace (steam);
                    var mapping_indent = steam_indent + "\t";
                    var mapping_content = "%s\"CompatToolMapping\"\n%s{\n%s}\n".printf (mapping_indent, mapping_indent, mapping_indent);
                    config_content = document.insert_before_closing_brace (steam, mapping_content);

                    document = Utils.VDF.VdfParser.parse_document (config_content);
                    if (document == null)
                        return false;

                    install_config_store = document.root.get_child ("InstallConfigStore");
                    software = install_config_store != null ? install_config_store.get_child ("Software") : null;
                    valve = software != null ? software.get_child ("Valve") : null;
                    steam = valve != null ? valve.get_child ("Steam") : null;
                    mapping = steam != null ? steam.get_child ("CompatToolMapping") : null;
                    if (mapping == null)
                        return false;
                }

                var mapping_indent = document.indentation_of_closing_brace (mapping);
                var entry_indent = mapping_indent + "\t";
                var entry_content = "%s\"%u\"\n%s{\n%s\t\"name\"\t\t%s\n%s\t\"config\"\t\t\"\"\n%s\t\"priority\"\t\t\"250\"\n%s}\n".printf (
                    entry_indent,
                    appid,
                    entry_indent,
                    entry_indent,
                    Utils.VDF.VdfDocument.quote (compatibility_tool),
                    entry_indent,
                    entry_indent,
                    entry_indent
                );
                config_content = document.insert_before_closing_brace (mapping, entry_content);
            }

            if (config_content == document.content) {
                this.compatibility_tool = compatibility_tool;
                if (is_non_steam)
                    _is_native = null;
                return true;
            }

            var modified = Utils.Filesystem.modify_file (config_path, config_content);
            if (!modified)
                return false;

            this.compatibility_tool = compatibility_tool;
            if (is_non_steam)
                _is_native = null;

            return true;
        }

        public bool change_launch_options (string launch_options, string localconfig_path) {
            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            if (configuration != null) {
                var outcome = configuration.change_game_launch_options (this, launch_options, localconfig_path);
                if (!outcome.accepted)
                    return false;
                this.launch_options = launch_options;
                var configured_launcher = launcher as Launchers.Steam;
                if (configured_launcher.profile != null && configured_launcher.profile.launch_options_hashtable != null)
                    configured_launcher.profile.launch_options_hashtable.set (appid, launch_options);
                return true;
            }
            var steam_launcher = launcher as Launchers.Steam;

            if (is_non_steam) {
                var escaped_launch_options = launch_options.replace ("\"", "\\\"");
                var shortcut = steam_launcher.profile.shortcuts.get_shortcut_by_name (name);
                shortcut.LaunchOptions = escaped_launch_options;

                steam_launcher.profile.shortcuts.replace_shortcut_by_name (name, shortcut);

                try {
                    steam_launcher.profile.shortcuts.save ();
                } catch (Error error) {
                    GLib.warning (error.message);

                    return false;
                }

                this.launch_options = launch_options;

                return true;
            }

            var config_content = Utils.Filesystem.get_file_content (localconfig_path);
            var document = Utils.VDF.VdfParser.parse_document (config_content);
            if (document == null)
                return false;

            var config_store = document.root.get_child ("UserLocalConfigStore");
            var software = config_store != null ? config_store.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null;
            var steam = valve != null ? valve.get_child ("Steam") : null;
            var apps = steam != null ? steam.get_child ("apps") : null;
            var app = apps != null ? apps.get_child (appid.to_string ()) : null;
            if (app == null || app.closing_brace_start == -1)
                return false;

            var launch_options_entry = app.get_child ("LaunchOptions");
            if (launch_options == "") {
                if (launch_options_entry != null)
                    config_content = document.remove_entry (launch_options_entry);
            } else if (launch_options_entry != null) {
                config_content = document.replace_value (launch_options_entry, launch_options);
            } else {
                var app_indent = document.indentation_of_closing_brace (app);
                var entry_indent = app_indent + "\t";
                var entry_content = "%s\"LaunchOptions\"\t\t%s\n".printf (entry_indent, Utils.VDF.VdfDocument.quote (launch_options));
                config_content = document.insert_before_closing_brace (app, entry_content);
            }

            if (config_content == document.content) {
                this.launch_options = launch_options;
                if (steam_launcher.profile != null && steam_launcher.profile.launch_options_hashtable != null)
                    steam_launcher.profile.launch_options_hashtable.set (appid, launch_options);
                return true;
            }

            var modified = Utils.Filesystem.modify_file (localconfig_path, config_content);
            if (!modified)
                return false;

            this.launch_options = launch_options;

            if (steam_launcher.profile != null && steam_launcher.profile.launch_options_hashtable != null)
                steam_launcher.profile.launch_options_hashtable.set (appid, launch_options);

            return true;
        }

        public class AwacyGame {
            public uint appid { get; set; }
            public string name { get; set; }
            public string status { get; set; }

            public AwacyGame (uint appid, string name, string status) {
                this.appid = appid;
                this.name = name;
                this.status = status;
            }

            public static async Gee.HashMap<uint, Models.Games.Steam.AwacyGame?> get_awacy_games () {
                var games = new Gee.HashMap<uint, Models.Games.Steam.AwacyGame?> ();

                var response = yield Utils.Web.get_request (
                    "https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/refs/heads/master/games.json",
                    Utils.Web.GetRequestType.OTHER
                );

                if (response.code != ReturnCode.VALID_REQUEST)
                    return games;

                var root_node = Utils.Parser.get_node_from_json (response.body);

                if (root_node == null)
                    return games;

                if (root_node.get_node_type () != Json.NodeType.ARRAY)
                    return games;

                var root_array = root_node.get_array ();
                if (root_array == null)
                    return games;

                for (var i = 0; i < root_array.get_length (); i++) {
                    var object = root_array.get_object_element (i);

                    var storeids_object = object.get_object_member ("storeIds");
                    if (storeids_object == null)
                        continue;

                    if (!storeids_object.has_member ("steam"))
                        continue;

                    uint appid = 0;
                    if (!uint.try_parse (storeids_object.get_string_member ("steam"), out appid))
                        continue;

                    if (!object.has_member ("slug"))
                        continue;

                    var name = object.get_string_member ("slug");

                    if (!object.has_member ("status"))
                        continue;

                    var status = object.get_string_member ("status");

                    var game = new AwacyGame (appid, name, status);

                    games.set (appid, game);
                }

                return games;
            }
        }
    }
}
