namespace ProtonPlus.Models {
    public abstract class Tool : Object {
        public string title { get; set; }
        public string description { get; set; }
        public Group group { get; set; }
        public bool has_more { get; set; }
        public bool has_latest_support { get; set; }
        public bool asset_position_hwcaps_condition { get; set; }
        public Utils.Web.GetRequestType get_request_type { get; set; }
        public Gee.LinkedList<Release> releases { get; set; default = new Gee.LinkedList<Release> (); }

        public async Gee.LinkedList<Release> get_releases_async (out ReturnCode code) {
            if (releases.size > 0) {
                code = ReturnCode.RELEASES_LOADED;
            } else {
                var new_releases = yield load_more (out code);

                if (code != ReturnCode.RELEASES_LOADED || new_releases.size == 0)
                return releases;

                foreach (var release in new_releases) {
                    releases.add (release);
                }

                if (this is Models.Tools.Basic && has_latest_support) {
                    var latest_release = new Models.Releases.Latest (this as Models.Tools.Basic, "%s Latest".printf (title), releases[0].description, releases[0].release_date, releases[0].download_url, releases[0].page_url);

                    releases.insert (0, latest_release);
                }
            }

            return releases;
        }

        public abstract async Gee.LinkedList<Release> load_more (out ReturnCode code);

        /// Checks all launchers for available updates and applies them.
        public static async ReturnCode check_for_updates (List<Launcher> launchers) {
            var latest_runners = new Gee.LinkedList<Models.Tools.Basic> ();

            foreach (var launcher in launchers) {
                if (launcher.groups == null) continue;

                foreach (var group in launcher.groups) {
                    var directories = group.get_tool_directories ();

                    foreach (var tool in group.tools) {
                        if (!tool.has_latest_support || !(tool is Models.Tools.Basic))
                        continue;

                        foreach (var directory in directories) {
                            if (directory == "%s Latest".printf (tool.title)) {
                                latest_runners.add (tool as Models.Tools.Basic);
                                continue;
                            }

                            if (directory == "%s Latest Backup".printf (tool.title)) {
                                var deleted_old_backup = yield Utils.Filesystem.delete_directory ("%s/%s/%s Latest Backup".printf (launcher.directory, group.directory, tool.title));
                                if (!deleted_old_backup) {
                                    warning ("Failed to delete old backup for %s", tool.title);
                                    return ReturnCode.UNKNOWN_ERROR;
                                }
                                continue;
                            }
                        }
                    }
                }
            }

            if (latest_runners.size == 0) {
                return ReturnCode.NOTHING_TO_UPDATE;
            }

            var updated_count = 0;

            foreach (var runner in latest_runners) {
                var code = yield update_specific_runner (runner);
                if (code == ReturnCode.RUNNER_UPDATED) {
                    updated_count++;
                } else if (code != ReturnCode.NOTHING_TO_UPDATE) {
                    return code;
                }
            }

            return updated_count > 0 ? ReturnCode.RUNNERS_UPDATED : ReturnCode.NOTHING_TO_UPDATE;
        }

        public static async ReturnCode update_specific_runner (Models.Tools.Basic runner) {
            string? response;

            string query_param;
            switch (runner.get_request_type) {
                case Utils.Web.GetRequestType.FORGEJO:
                    query_param = "limit=1";
                    break;
                case Utils.Web.GetRequestType.GITHUB:
                case Utils.Web.GetRequestType.GITLAB:
                default:
                    query_param = "per_page=1";
                    break;
            }

            var base_runner_directory = "%s%s".printf (runner.group.launcher.directory, runner.group.directory);
            var runner_directory = "%s/%s Latest".printf (base_runner_directory, runner.title);
            var tag_path = "%s/.protonplus_tag".printf (runner_directory);

            var code = yield Utils.Web.get_request ("%s?%s".printf (runner.endpoint, query_param), runner.get_request_type, out response);

            if (code != ReturnCode.VALID_REQUEST) {
            // If API is unavailable but we have a tag file, assume up to date
                if (FileUtils.test (tag_path, FileTest.IS_REGULAR))
                return ReturnCode.NOTHING_TO_UPDATE;
                return code;
            }

            var root_node = Utils.Parser.get_node_from_json (response);
            if (root_node == null)
            return ReturnCode.UNKNOWN_ERROR;

            if (root_node.get_node_type () != Json.NodeType.ARRAY)
            return ReturnCode.UNKNOWN_ERROR;

            var root_array = root_node.get_array ();
            if (root_array == null)
            return ReturnCode.UNKNOWN_ERROR;

            if (root_array.get_length () != 1)
            return ReturnCode.UNKNOWN_ERROR;

            var object = root_array.get_object_element (0);

            var asset_array = object.get_array_member ("assets");
            if (asset_array == null)
            return ReturnCode.UNKNOWN_ERROR;

            string title = object.get_string_member ("tag_name");
            string description = object.get_string_member ("body").strip ();
            string page_url = object.get_string_member ("html_url");
            string release_date = object.get_string_member ("created_at").split ("T")[0];
            string download_url = "";

            var real_asset_position = runner.asset_position;
            if (runner.asset_position_hwcaps_condition) {
                for (int y = 0; y < asset_array.get_length (); y++) {
                    var asset_object = asset_array.get_object_element (y);

                    if (asset_object.get_string_member ("name").contains ("%s.tar.xz".printf (Globals.HWCAPS.nth_data (0)))) {
                        real_asset_position = y;

                        break;
                    }
                }
            }

            if (asset_array.get_length () - 1 >= real_asset_position) {
                var asset_object = asset_array.get_object_element (real_asset_position);

                download_url = asset_object.get_string_member ("browser_download_url");
            }

            if (download_url == "" || !download_url.contains (".tar"))
            return ReturnCode.UNKNOWN_ERROR;

            if (FileUtils.test (tag_path, FileTest.IS_REGULAR)) {
                var stored_tag = Utils.Filesystem.get_file_content (tag_path).strip ();
                if (stored_tag != "" && title == stored_tag)
                return ReturnCode.NOTHING_TO_UPDATE;
            }

            var version_content = Utils.Filesystem.get_file_content ("%s/version".printf (runner_directory));
            if (version_content == "")
            return ReturnCode.UNKNOWN_ERROR;

            var version_title = version_content.split (" ")[1].strip ();

            var proton_content = Utils.Filesystem.get_file_content ("%s/proton".printf (runner_directory));
            if (proton_content == "")
            return ReturnCode.UNKNOWN_ERROR;

            var proton_start_word = "CURRENT_PREFIX_VERSION=\"";
            var proton_start_index = proton_content.index_of (proton_start_word, 0);
            if (proton_start_index == -1)
            return ReturnCode.UNKNOWN_ERROR;
            proton_start_index += proton_start_word.length;

            var proton_end_index = proton_content.index_of ("\"", proton_start_index);
            if (proton_end_index == -1)
            return ReturnCode.UNKNOWN_ERROR;

            var proton_title = proton_content.substring (proton_start_index, proton_end_index - proton_start_index);

            if (title == version_title || title == proton_title) {
                Utils.Filesystem.create_file (tag_path, title);
                return ReturnCode.NOTHING_TO_UPDATE;
            }

            var backup_runner_directory = "%s/%s Latest Backup".printf (base_runner_directory, runner.title);

            var moved = yield Utils.Filesystem.move_directory (runner_directory, backup_runner_directory);
            if (!moved)
            return ReturnCode.UNKNOWN_ERROR;

            var release = new Models.Releases.Latest (runner as Models.Tools.Basic, "%s Latest".printf (runner.title), description, release_date, download_url, page_url);
            release.state = Models.Release.State.BUSY_UPDATING;

            var installed = yield release.install ();
            if (!installed) {
                var deleted = yield Utils.Filesystem.delete_directory (runner_directory);

                if (deleted)
                yield Utils.Filesystem.move_directory (backup_runner_directory, runner_directory);

                return ReturnCode.UNKNOWN_ERROR;
            }

            var backup_settings_path = "%s/user_settings.py".printf (backup_runner_directory);
            var backup_settings_exists = FileUtils.test (backup_settings_path, FileTest.IS_REGULAR);
            var backup_settings_is_symlink = backup_settings_exists ? FileUtils.test (backup_settings_path, FileTest.IS_SYMLINK) : false;
            if (backup_settings_exists) {
                var settings_path = "%s/user_settings.py".printf (runner_directory);
                if (backup_settings_is_symlink) {
                    var copied = Utils.Filesystem.copy_symlink (backup_settings_path, settings_path);
                    if (!copied)
                    return ReturnCode.UNKNOWN_ERROR;
                } else {
                    Utils.Filesystem.create_file (settings_path, Utils.Filesystem.get_file_content (backup_settings_path));
                }
            }

            Utils.Filesystem.create_file (tag_path, title);

            var deleted = yield Utils.Filesystem.delete_directory (backup_runner_directory);
            if (!deleted)
            return ReturnCode.UNKNOWN_ERROR;

            return ReturnCode.RUNNER_UPDATED;
        }
    }
}
