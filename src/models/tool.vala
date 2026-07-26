namespace ProtonPlus.Models {
    public abstract class Tool : Object {
        public string title { get; set; }
        public string description { get; set; }
        public Group group { get; set; }
        public bool has_more { get; set; }
        public bool legacy { get; set; }
        public string last_updated { get; set; }
        public int page { get; set; default = 1; }
        public int sort_priority { get; set; default = 1000; }
        private string? _last_version = null;

        public Utils.Web.GetRequestType get_request_type { get; set; }
        public Gee.LinkedList<Release> releases { get; set; default = new Gee.LinkedList<Release> (); }
        public Gee.LinkedList<Variant> variants { get; set; default = new Gee.LinkedList<Variant> (); }

        construct {
            // Be explicit: some construction paths may not honor property defaults reliably.
            if (releases == null)
                releases = new Gee.LinkedList<Release> ();
            if (variants == null)
                variants = new Gee.LinkedList<Variant> ();
        }

        public virtual bool is_installed () {
            return false;
        }

        public virtual bool is_used () {
            return false;
        }

        public string? last_version {
            owned get {
                if (_last_version != null && _last_version.length > 0)
                    return _last_version;

                if (this.releases == null || this.releases.size == 0) {
                    return "";
                }

                Release? lastRelease = null;
                if (this.releases.size > 1) {
                    lastRelease = this.releases.get (1);
                } else {
                    lastRelease = this.releases.get (0);
                }

                if (lastRelease == null) {
                    return "";
                }

                string title = lastRelease.title;

                if (title == null || title == "") {
                    return "";
                }

                try {
                    var regex = new GLib.Regex ("(\\d+[\\d\\.\\-]+?)(?:-[sS][lL][rR]|-[hH][dD][rR])?$", GLib.RegexCompileFlags.OPTIMIZE);
                    GLib.MatchInfo match;

                    if (regex.match (title, 0, out match)) {
                        string version = match.fetch (1);

                        if (version.has_suffix ("-")) {
                            version = version.substring (0, version.length - 1);
                        }
                        this._last_version = version;
                        return version;
                    }
                } catch (GLib.RegexError e) {
                    warning ("Could not parse the release version: %s", e.message);
                }

                return title;
            }
            set {
                _last_version = value;
            }
        }

        public async Gee.LinkedList<Release> get_releases_async (bool force_fetch, out ReturnCode code) {
            if (releases == null)
                releases = new Gee.LinkedList<Release> ();

            if (releases.size > 0 && !force_fetch) {
                code = ReturnCode.RELEASES_LOADED;
            } else {
                if (!force_fetch) {
                    yield Utils.CacheManager.load_releases (this);

                    if (releases.size > 0) {
                        var needs_variant_refresh = false;
                        var basic_tool = this as Models.Tools.Basic;

                        if (basic_tool != null && variants != null && variants.size > 0) {
                            foreach (var cached_release in releases) {
                                if (cached_release.variants == null || cached_release.variants.size != variants.size) {
                                    needs_variant_refresh = true;
                                    break;
                                }

                                // A runner can change the filename pattern of a
                                // single default variant.  Keep its cached URL
                                // only when that pattern still matches.
                                for (var i = 0; i < variants.size; i++) {
                                    var configured_variant = variants.get (i);
                                    var cached_variant = cached_release.variants.get (i);

                                    if (cached_variant.name != configured_variant.name ||
                                        cached_variant.format != configured_variant.format ||
                                        cached_variant.is_default != configured_variant.is_default) {
                                        needs_variant_refresh = true;
                                        break;
                                    }
                                }

                                if (needs_variant_refresh)
                                    break;

                                var default_variant_has_url = true;
                                foreach (var cached_variant in cached_release.variants) {
                                    if (cached_variant.is_default) {
                                        default_variant_has_url = cached_variant.download_url != null && cached_variant.download_url != "";
                                        break;
                                    }
                                }

                                if (!default_variant_has_url) {
                                    needs_variant_refresh = true;
                                    break;
                                }

                                for (var i = 0; i < cached_release.variants.size - 1; i++) {
                                    var left_variant = cached_release.variants.get (i);
                                    if (left_variant.download_url == null || left_variant.download_url == "")
                                        continue;

                                    for (var j = i + 1; j < cached_release.variants.size; j++) {
                                        var right_variant = cached_release.variants.get (j);
                                        if (right_variant.download_url == null || right_variant.download_url == "")
                                            continue;

                                        if (left_variant.format != right_variant.format && left_variant.download_url == right_variant.download_url) {
                                            needs_variant_refresh = true;
                                            break;
                                        }
                                    }

                                    if (needs_variant_refresh)
                                        break;
                                }

                                if (needs_variant_refresh)
                                    break;
                            }
                        }

                        if (!needs_variant_refresh) {
                            code = ReturnCode.RELEASES_LOADED;
                            return releases;
                        }

                        // Cached releases without per-release variants are stale for variant filtering.
                        page = 1;
                    }
                } else {
                    page = 1;
                }

                var new_releases = yield load_more (out code);

                if (code != ReturnCode.RELEASES_LOADED || new_releases.size == 0)
                    return releases;

                releases.clear ();
                _last_version = null;
                foreach (var release in new_releases) {
                    releases.add (release);
                }

                if (this is Models.Tools.Basic) {
                    var latest_release = new Models.Releases.Latest (
                        this as Models.Tools.Basic,
                        "%s Latest".printf (title),
                        releases[0].description,
                        releases[0].release_date,
                        releases[0].download_url,
                        releases[0].page_url,
                        releases[0].title
                    );

                    foreach (var variant in releases[0].variants) {
                        latest_release.variants.add (new Models.Variant (
                            variant.name,
                            variant.format,
                            variant.is_default,
                            this as Models.Tools.Basic,
                            variant.download_url
                        ));
                    }

                    releases.insert (0, latest_release);
                }

                last_updated = new DateTime.now_local ().format_iso8601 ();
                yield Utils.CacheManager.save_releases (this);
            }

            return releases;
        }

        public abstract async Gee.LinkedList<Release> load_more (out ReturnCode code);

        /// Checks all launchers for available updates and applies them.
        public static async ReturnCode check_for_updates (List<Launcher> launchers) {
            var processes = (yield Utils.System.run_command ("ps -eo args")).stdout.ascii_down ();
            if (processes.contains ("/proton") ||
                processes.contains ("/umu") ||
                processes.contains ("/wine") ||
                processes.contains ("/wine64") ||
                processes.contains (".exe")) {
                return ReturnCode.RUNNERS_IN_USE;
            }

            var latest_runners = new Gee.LinkedList<Models.Tools.Basic> ();

            foreach (var launcher in launchers) {
                if (launcher.groups == null)
                    continue;

                foreach (var group in launcher.groups) {
                    var directories = group.get_tool_directories ();

                    foreach (var tool in group.tools) {
                        if (!(tool is Models.Tools.Basic))
                            continue;

                        foreach (var directory in directories) {
                            if (directory == "%s Latest".printf (tool.title)) {
                                latest_runners.add (tool as Models.Tools.Basic);
                                continue;
                            }

                            if (directory == "%s Latest Backup".printf (tool.title)) {
                                var backup_directory = "%s/%s/%s Latest Backup".printf (
                                    launcher.directory,
                                    group.directory,
                                    tool.title
                                );
                                var deleted_old_backup = yield Utils.Filesystem.delete_directory (backup_directory);

                                if (!deleted_old_backup) {
                                    warning ("Failed to delete old backup for %s", tool.title);
                                    return ReturnCode.FILESYSTEM_ERROR;
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
            var base_runner_directory = "%s%s".printf (runner.group.launcher.directory, runner.group.directory);
            var runner_directory = "%s/%s Latest".printf (base_runner_directory, runner.title);
            var metadata = Utils.Metadata.load (runner_directory);

            if (!FileUtils.test (runner_directory, FileTest.IS_DIR))
                return ReturnCode.RUNNER_NOT_INSTALLED;

            metadata.runner_endpoint = runner.endpoint;
            metadata.runner_title = runner.title;
            metadata.save (runner_directory);

            string title = "";
            string description = "";
            string page_url = "";
            string release_date = "";
            string download_url = "";

            if (runner is Models.Tools.GitHubAction) {
                var source_runner = runner.source_runner;
                if (source_runner == null)
                    return ReturnCode.INVALID_CONFIGURATION;

                Models.Internal.Requests.GithubAction.Release? latest_action = null;

                ReturnCode fast_request_code;
                var fast_releases = yield source_runner.request_releases (1, 1, out fast_request_code);
                if (fast_request_code != ReturnCode.RELEASES_LOADED || fast_releases == null)
                    return fast_request_code;

                if (fast_releases.list.size > 0) {
                    var first_release = fast_releases.list.get (0) as Models.Internal.Requests.GithubAction.Release;
                    if (first_release != null && first_release.status == "completed" && first_release.conclusion == "success")
                        latest_action = first_release;
                }

                var current_page = 1;
                var reached_end = false;
                const int PAGE_SIZE_FALLBACK = 25;

                while (latest_action == null && !reached_end) {
                    ReturnCode request_code;
                    var source_releases = yield source_runner.request_releases (current_page, PAGE_SIZE_FALLBACK, out request_code);
                    if (request_code != ReturnCode.RELEASES_LOADED || source_releases == null)
                        return request_code;

                    foreach (var source_release_item in source_releases.list) {
                        var source_release = source_release_item as Models.Internal.Requests.GithubAction.Release;
                        if (source_release == null)
                            continue;

                        if (source_release.status == "completed" && source_release.conclusion == "success") {
                            latest_action = source_release;
                            break;
                        }
                    }

                    reached_end = source_releases.list.size < PAGE_SIZE_FALLBACK;
                    current_page++;
                }

                if (latest_action == null)
                    return ReturnCode.NOTHING_TO_UPDATE;

                var action_runner = runner as Models.Tools.GitHubAction;
                title = latest_action.title;
                page_url = latest_action.page_url;
                release_date = latest_action.created_at.format_iso8601 ();
                download_url = action_runner.url_template.replace ("{id}", latest_action.id.to_string ());
            } else {
                string query_param;
                switch (runner.get_request_type) {
                case Utils.Web.GetRequestType.FORGEJO :
                    query_param = "limit=1";
                    break;
                case Utils.Web.GetRequestType.GITHUB:
                case Utils.Web.GetRequestType.GITLAB:
                default:
                    query_param = "per_page=1";
                    break;
                }

                var response = yield Utils.Web.get_request ("%s?%s".printf (runner.endpoint, query_param), runner.get_request_type);
                var code = response.code;

                if (code != ReturnCode.VALID_REQUEST) {
                    // If API is unavailable but we have a stored tag, assume up to date.
                    if (metadata.tag != "")
                        return ReturnCode.NOTHING_TO_UPDATE;
                    return code;
                }

                var root_node = Utils.Parser.get_node_from_json (response.body);
                if (root_node == null)
                    return ReturnCode.INVALID_DATA;

                if (root_node.get_node_type () != Json.NodeType.ARRAY)
                    return ReturnCode.INVALID_DATA;

                var root_array = root_node.get_array ();
                if (root_array == null)
                    return ReturnCode.INVALID_DATA;

                if (root_array.get_length () != 1)
                    return ReturnCode.INVALID_DATA;

                var object = root_array.get_object_element (0);

                var asset_array = object.get_array_member ("assets");
                if (asset_array == null)
                    return ReturnCode.INVALID_DATA;

                title = object.get_string_member ("tag_name");
                description = object.get_string_member ("body").strip ();
                page_url = object.get_string_member ("html_url");
                release_date = object.get_string_member ("created_at").split ("T")[0];

                var release_assets = new Gee.LinkedList<Models.Internal.Assets.IAsset> ();
                string? fallback_download_url = null;

                for (int y = 0; y < asset_array.get_length (); y++) {
                    var asset_object = asset_array.get_object_element (y);
                    if (asset_object == null)
                        continue;

                    var asset_name = asset_object.get_string_member_with_default ("name", "");
                    var asset_download_url = asset_object.get_string_member_with_default ("browser_download_url", "");
                    if (asset_name == "" || asset_download_url == "")
                        continue;

                    var asset = new Models.Internal.Assets.Asset (asset_name, asset_download_url);
                    if (!asset.is_archive ())
                        continue;

                    if (fallback_download_url == null)
                        fallback_download_url = asset_download_url;

                    release_assets.add (asset);
                }

                if (release_assets.size > 0) {
                    var release_variants = runner.create_release_variants (title, title, release_assets, fallback_download_url);
                    var default_variant_download_url = runner.get_default_variant_download_url (release_variants, fallback_download_url);

                    if (default_variant_download_url != null)
                        download_url = default_variant_download_url;
                }
            }

            if (download_url == "" || !Models.Internal.Assets.Asset.is_archive_name (download_url))
                return ReturnCode.INVALID_DATA;

            if (metadata.tag != "" && title == metadata.tag)
                return ReturnCode.NOTHING_TO_UPDATE;

            var version_content = Utils.Filesystem.get_file_content ("%s/version".printf (runner_directory));
            var proton_content = Utils.Filesystem.get_file_content ("%s/proton".printf (runner_directory));
            if (version_content != "" && proton_content != "") {
                var version_title_parts = version_content.split (" ");
                if (version_title_parts.length > 1) {
                    var version_title = version_title_parts[1].strip ();
                    var proton_start_word = "CURRENT_PREFIX_VERSION=\"";
                    var proton_start_index = proton_content.index_of (proton_start_word, 0);
                    if (proton_start_index != -1) {
                        proton_start_index += proton_start_word.length;

                        var proton_end_index = proton_content.index_of ("\"", proton_start_index);
                        if (proton_end_index != -1) {
                            var proton_title = proton_content.substring (proton_start_index, proton_end_index - proton_start_index);
                            if (title == version_title || title == proton_title) {
                                metadata.tag = title;
                                metadata.save (runner_directory);
                                return ReturnCode.NOTHING_TO_UPDATE;
                            }
                        }
                    }
                }
            }

            var release = new Models.Releases.Latest (
                runner as Models.Tools.Basic,
                "%s Latest".printf (runner.title),
                description,
                release_date,
                download_url,
                page_url,
                title
            );
            release.state = Models.Release.State.BUSY_UPDATING;

            // The release stages the new files, then atomically swaps them with
            // this runner.  The previous runner remains available for settings
            // migration and rollback until this whole update succeeds.
            var install_code = yield release.install_replacement ();
            if (install_code != ReturnCode.RUNNER_INSTALLED)
                return install_code;

            var backup_runner_directory = release.replacement_backup_path;
            if (backup_runner_directory == null || !FileUtils.test (backup_runner_directory, FileTest.IS_DIR))
                return ReturnCode.FILESYSTEM_ERROR;

            var backup_settings_path = "%s/user_settings.py".printf (backup_runner_directory);
            var backup_settings_exists = FileUtils.test (backup_settings_path, FileTest.IS_REGULAR);
            var backup_settings_is_symlink = backup_settings_exists ? FileUtils.test (backup_settings_path, FileTest.IS_SYMLINK) : false;
            if (backup_settings_exists) {
                var settings_path = "%s/user_settings.py".printf (runner_directory);
                if (backup_settings_is_symlink) {
                    var copied = Utils.Filesystem.copy_symlink (backup_settings_path, settings_path);
                    if (!copied) {
                        yield rollback_replaced_runner (runner_directory, backup_runner_directory);
                        return ReturnCode.FILESYSTEM_ERROR;
                    }
                } else {
                    Utils.Filesystem.create_file (settings_path, Utils.Filesystem.get_file_content (backup_settings_path));
                }
            }

            var migrate_default_prefix = Globals.SETTINGS != null && Globals.SETTINGS.get_boolean ("migrate-default-prefix");
            var backup_default_prefix_path = "%s/files/share/default_pfx".printf (backup_runner_directory);
            if (migrate_default_prefix && FileUtils.test (backup_default_prefix_path, FileTest.IS_DIR)) {
                var default_prefix_path = "%s/files/share/default_pfx".printf (runner_directory);

                if (FileUtils.test (default_prefix_path, FileTest.IS_DIR)) {
                    var deleted_default_prefix = yield Utils.Filesystem.delete_directory (default_prefix_path);
                    if (!deleted_default_prefix) {
                        yield rollback_replaced_runner (runner_directory, backup_runner_directory);
                        return ReturnCode.FILESYSTEM_ERROR;
                    }
                }

                var copied = yield Utils.Filesystem.copy_directory (backup_default_prefix_path, default_prefix_path);
                if (!copied) {
                    yield rollback_replaced_runner (runner_directory, backup_runner_directory);
                    return ReturnCode.FILESYSTEM_ERROR;
                }
            }

            var deleted = yield Utils.Filesystem.delete_directory (backup_runner_directory);
            if (!deleted)
                return ReturnCode.FILESYSTEM_ERROR;

            return ReturnCode.RUNNER_UPDATED;
        }

        private static async bool rollback_replaced_runner (string runner_directory, string backup_runner_directory) {
            var failed_runner_directory = "%s.failed".printf (backup_runner_directory);
            if (!yield Utils.Filesystem.move_directory_atomic (runner_directory, failed_runner_directory))
                return false;

            if (!yield Utils.Filesystem.move_directory_atomic (backup_runner_directory, runner_directory)) {
                yield Utils.Filesystem.move_directory_atomic (failed_runner_directory, runner_directory);
                return false;
            }

            return yield Utils.Filesystem.delete_directory (failed_runner_directory);
        }
    }
}
