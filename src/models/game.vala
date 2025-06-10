namespace ProtonPlus.Models {
    public struct AwacyGame {
        int appid;
        string name;
        string status;
    }

    public class Game : Object {
        public int appid { get; set; }
        public string name { get; set; }
        public string installdir { get; set; }
        public int library_folder_id { get; set; }
        public string library_folder_path { get; set; }
        public string awacy_name { get; set; }
        public string awacy_status { get; set; }
        public string compat_tool { get; set; }
        public Launchers.Steam launcher { get; set; }

        public Game(int appid, string name, string installdir, int library_folder_id, string library_folder_path, Launchers.Steam launcher) {
            this.appid = appid;
            this.name = name;
            this.installdir = installdir;
            this.library_folder_id = library_folder_id;
            this.library_folder_path = library_folder_path;
            this.launcher = launcher;
        }

        public bool set_compatibility_tool(string compat_tool) {
            var config_path = "%s/config/config.vdf".printf(launcher.directory);
            var config_content = Utils.Filesystem.get_file_content(config_path);
            var compat_tool_mapping_content = "";
            var compat_tool_mapping_item = "";
            var compat_tool_mapping_item_appid = 0;
            var compat_tool_mapping_item_name = "";
            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;
            var current_position = 0;

            start_text = "CompatToolMapping\"\n\t\t\t\t";
            end_text = "\n\t\t\t\t}";
            start_pos = config_content.index_of(start_text, 0) + start_text.length;
            end_pos = config_content.index_of(end_text, start_pos);
            compat_tool_mapping_content = config_content.substring(start_pos, end_pos - start_pos);
            // message("start: %i, end: %i, compat_tool_mapping_content: %s", start_pos, end_pos, compat_tool_mapping_content);

            while (true) {
                start_text = "\"";
                end_text = "}";
                start_pos = compat_tool_mapping_content.index_of(start_text, current_position);

                if (start_pos == -1)
                    break;

                end_pos = compat_tool_mapping_content.index_of(end_text, start_pos) + 1;
                compat_tool_mapping_item = compat_tool_mapping_content.substring(start_pos, end_pos - start_pos);
                current_position = end_pos;
                // message("start: %i, end: %i, compat_tool_mapping_item: %s", start_pos, end_pos, compat_tool_mapping_item);

                start_text = "\"";
                end_text = "\"";
                start_pos = compat_tool_mapping_item.index_of(start_text, 0) + start_text.length;
                end_pos = compat_tool_mapping_item.index_of(end_text, start_pos);
                var compat_tool_mapping_item_appid_valid = int.try_parse(compat_tool_mapping_item.substring(start_pos, end_pos - start_pos), out compat_tool_mapping_item_appid);
                if (!compat_tool_mapping_item_appid_valid)
                    return false;
                // message("start: %i, end: %i, compat_tool_mapping_item_appid: %i", start_pos, end_pos, compat_tool_mapping_item_appid);

                if (compat_tool_mapping_item_appid != appid)
                    continue;

                if (compat_tool == _("Undefined")) {
                    start_pos = config_content.index_of(compat_tool_mapping_item, 0) - 6;
                    end_pos = config_content.index_of(compat_tool_mapping_item, start_pos);

                    var config_content_modified = config_content.splice(start_pos, end_pos, null);

                    config_content_modified = config_content_modified.replace(compat_tool_mapping_item, "");

                    Utils.Filesystem.modify_file(config_path, config_content_modified);

                    this.compat_tool = compat_tool;

                    return true;
                }

                start_text = "name\"\t\t\"";
                end_text = "\"";
                start_pos = compat_tool_mapping_item.index_of(start_text, 0) + start_text.length;
                end_pos = compat_tool_mapping_item.index_of(end_text, start_pos);
                compat_tool_mapping_item_name = compat_tool_mapping_item.substring(start_pos, end_pos - start_pos);
                // message("start: %i, end: %i, compat_tool_mapping_item_name: %s", start_pos, end_pos, compat_tool_mapping_item_name);

                var compat_tool_mapping_item_modified = compat_tool_mapping_item.replace(compat_tool_mapping_item_name, compat_tool);

                var config_content_modified = config_content.replace(compat_tool_mapping_item, compat_tool_mapping_item_modified);

                Utils.Filesystem.modify_file(config_path, config_content_modified);

                this.compat_tool = compat_tool;

                return true;
            }

            if (compat_tool == _("Undefined"))
                return true;

            var line1 = "\n\t\t\t\t\t\"%i\"\n".printf(appid);
            var line2 = "\t\t\t\t\t{\n";
            var line3 = "\t\t\t\t\t\t\"name\"\t\t\"%s\"\n".printf(compat_tool);
            var line4 = "\t\t\t\t\t\t\"config\"\t\t\"%s\"\n".printf("");
            var line5 = "\t\t\t\t\t\t\"priority\"\t\t\"%i\"\n".printf(250);
            var line6 = "\t\t\t\t\t}";
            var new_item = line1 + line2 + line3 + line4 + line5 + line6;

            var compat_tool_mapping_item_modified = compat_tool_mapping_item + new_item;

            var config_content_modified = config_content.replace(compat_tool_mapping_item, compat_tool_mapping_item_modified);

            Utils.Filesystem.modify_file(config_path, config_content_modified);

            this.compat_tool = compat_tool;

            return true;
        }

        public bool set_launch_options(string launch_options) {
            int count = 0;

            foreach(var location in launcher.get_userdata_locations()) {
                var config_path = "%s/config/localconfig.vdf".printf(location);
                var config_content = Utils.Filesystem.get_file_content(config_path);
                var start_text = "";
                var end_text = "";
                var start_pos = 0;
                var end_pos = 0;
                var app = "";
                var app_launch_options = "";
                var app_modified = "";

                start_text = "%i\"\n\t\t\t\t\t{".printf(appid);
                end_text = "\n\t\t\t\t\t}";
                start_pos = config_content.index_of(start_text, 0) + start_text.length;

                if (start_pos == -1)
                    continue;

                end_pos = config_content.index_of(end_text, start_pos);
                app = config_content.substring(start_pos, end_pos - start_pos);
                // message("start: %i, end: %i, app: %s", start_pos, end_pos, app);

                if (launch_options.length == 0) {
                    if (app.contains("LaunchOptions")) {
                        start_text = "\n\t\t\t\t\t\t\"LaunchOptions\"\t\t\"";
                        end_text = "\"";
                        start_pos = app.index_of(start_text, 0);

                        if (start_pos == -1)
                            continue;

                        end_pos = app.index_of(end_text, start_pos + start_text.length) + 1;
                        app_launch_options = app.substring(start_pos, end_pos - start_pos);
                        // message("start: %i, end: %i, app_launch_options: %s", start_pos, end_pos, app_launch_options);

                        app_modified = app.replace(app_launch_options, "");
                    }
                } else {
                    if (app.contains("LaunchOptions")) {
                        start_text = "LaunchOptions\"\t\t\"";
                        end_text = "\"";
                        start_pos = app.index_of(start_text, 0) + start_text.length;

                        if (start_pos == -1)
                            continue;

                        end_pos = app.index_of(end_text, start_pos);
                        app_launch_options = app.substring(start_pos, end_pos - start_pos);
                        // message("start: %i, end: %i, app_launch_options: %s", start_pos, end_pos, app_launch_options);
                    
                        app_modified = app.replace(app_launch_options, launch_options);
                    } else {
                        app_launch_options = "\n\t\t\t\t\t\t\"LaunchOptions\"\t\t\"%s\"".printf(launch_options);

                        app_modified = app.concat(app_launch_options);
                    }
                }
                
                config_content = config_content.replace(app, app_modified);

                Utils.Filesystem.modify_file(config_path, config_content);

                count++;
            }
            
            return count > 0;
        }
    }
}