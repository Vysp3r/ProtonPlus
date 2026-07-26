namespace ProtonPlus.Models {
    public abstract class Tool : Object {
        // This is a serialized runtime identity.  Its components remain
        // available through group and provider_id.
        public string id { get; internal set; default = ""; }
        public string provider_id { get; internal set; default = ""; }
        public string source_id { get; internal set; default = ""; }
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

        internal void set_identity (string provider_id, string source_id) {
            this.provider_id = provider_id;
            this.source_id = source_id;
            this.id = "%s/%s/%s".printf (group.launcher.instance_id, group.id, provider_id);
        }

        private static void persist_runner_identity (
            Utils.Metadata metadata,
            Models.Tools.Basic runner,
            string directory_path,
            string tag = "",
            string release_id = ""
        ) {
            metadata.runner_endpoint = runner.endpoint;
            metadata.runner_title = runner.title;
            metadata.provider_id = runner.provider_id;
            metadata.tool_id = runner.id;
            metadata.launcher_id = runner.group.launcher.instance_id;
            foreach (var variant in runner.variants) {
                if (variant.is_default) {
                    metadata.variant_id = variant.id;
                    break;
                }
            }
            if (tag != "")
                metadata.tag = tag;
            if (release_id != "")
                metadata.release_id = release_id;
            metadata.save (directory_path);
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
                    releases.insert (0, Models.Releases.Latest.from_release (
                        this as Models.Tools.Basic,
                        releases[0]
                    ));
                }

                last_updated = new DateTime.now_local ().format_iso8601 ();
                yield Utils.CacheManager.save_releases (this);
            }

            return releases;
        }

        // Stateful browsing entrypoint.  Basic tools implement this by
        // applying their provider-neutral ReleasePage result to page and
        // has_more; non-provider tools keep their specialized behavior.
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

        // Update discovery must use the same normalized release selected by
        // browsing, without changing the tool's browse pagination state.
        public static async Models.Releases.Latest? lookup_latest_runner_release (
            Models.Tools.Basic runner,
            out ReturnCode code
        ) {
            var source_release = yield runner.fetch_latest_eligible_release (out code);
            if (code != ReturnCode.RELEASES_LOADED || source_release == null)
                return null;

            return Models.Releases.Latest.from_release (runner, source_release);
        }

        private static bool is_request_failure (ReturnCode code) {
            switch (code) {
            case ReturnCode.REQUEST_FAILED:
            case ReturnCode.CONNECTION_ISSUE:
            case ReturnCode.CONNECTION_REFUSED:
            case ReturnCode.CONNECTION_UNKNOWN:
            case ReturnCode.API_LIMIT_REACHED:
            case ReturnCode.INVALID_ACCESS_TOKEN:
            case ReturnCode.TLS_HANDSHAKE_ERROR:
                return true;
            default:
                return false;
            }
        }

        public static async ReturnCode update_specific_runner (Models.Tools.Basic runner) {
            var base_runner_directory = "%s%s".printf (runner.group.launcher.directory, runner.group.directory);
            var runner_directory = "%s/%s Latest".printf (base_runner_directory, runner.title);
            var metadata = Utils.Metadata.load (runner_directory);

            if (!FileUtils.test (runner_directory, FileTest.IS_DIR))
                return ReturnCode.RUNNER_NOT_INSTALLED;

            ReturnCode lookup_code;
            var release = yield lookup_latest_runner_release (runner, out lookup_code);
            if (lookup_code != ReturnCode.RELEASES_LOADED) {
                // Keep the legacy fallback only for transport/API failures.
                // Invalid normalized data must remain visible to the caller.
                if (!(runner is Models.Tools.GitHubAction) &&
                    metadata.tag != "" && is_request_failure (lookup_code))
                    return ReturnCode.NOTHING_TO_UPDATE;
                return lookup_code;
            }

            if (release == null)
                return ReturnCode.NOTHING_TO_UPDATE;

            if (!release.asset.is_archive ())
                return ReturnCode.INVALID_DATA;

            var source_title = release.source_tag != "" ? release.source_tag : release.source_release_title;
            if (metadata.tag != "" && source_title == metadata.tag)
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
                            if (source_title == version_title || source_title == proton_title) {
                                persist_runner_identity (
                                    metadata,
                                    runner,
                                    runner_directory,
                                    source_title,
                                    release.upstream_release_id
                                );
                                return ReturnCode.NOTHING_TO_UPDATE;
                            }
                        }
                    }
                }
            }

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

            var migrate_default_prefix = Globals.SETTINGS != null && Globals.SETTINGS.get_boolean ("migrate-default-prefix");
            return yield finalize_replaced_runner (runner_directory, backup_runner_directory, migrate_default_prefix);
        }

        // This is the post-promotion half of an update.  It is kept separate
        // from release discovery so the local migration and rollback contract
        // can be exercised without a network request.
        public static async ReturnCode finalize_replaced_runner (
            string runner_directory,
            string backup_runner_directory,
            bool migrate_default_prefix
        ) {
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
