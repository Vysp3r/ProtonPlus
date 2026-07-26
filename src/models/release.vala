namespace ProtonPlus.Models {
    public class Release : Object {

        public enum Step {
            NOTHING,
            DOWNLOADING,
            EXTRACTING,
            MOVING,
            REMOVING,
        }

        public enum State {
            NOT_INSTALLED,
            UPDATE_AVAILABLE,
            UP_TO_DATE,
            BUSY_INSTALLING,
            BUSY_REMOVING,
            BUSY_UPDATING,
        }

        public Tool runner { get; set; }
        public string title { get; set; }
        public string displayed_title { get; set; }
        public string description { get; set; }
        public string release_date { get; set; }
        public ProtonPlus.Models.Assets.Asset asset { get; set; }
        public string page_url { get; set; }
        // Upstream values are opaque and must not be derived from the display title.
        public string upstream_release_id { get; set; default = ""; }
        public string source_tag { get; set; default = ""; }
        private bool _canceled = false;
        protected Cancellable operation_cancellable = new Cancellable ();
        public bool canceled {
            get { return _canceled; }
            set {
                if (_canceled == value)
                    return;

                _canceled = value;
                if (_canceled)
                    operation_cancellable.cancel ();

                notify_property ("canceled");
            }
        }
        public string progress { get; set; }
        public double speed_kbps { get; set; }
        public double seconds_remaining { get; set; }
        public bool is_percent { get; set; }
        public signal void progress_updated ();
        public bool is_finished { get; set; default = false; }
        public bool install_success { get; set; default = false; }
        public string? error_message { get; set; }
        public string install_location { get; set; }
        public int64 download_size { get; set; }
        protected string destination_path { get; set; }
        // Kept only while a replacement is being finalized.  Callers that
        // migrate user data can roll back by promoting this directory again.
        public string? replacement_backup_path { get; protected set; default = null; }
        public Gee.LinkedList<Variant> variants { get; set; default = new Gee.LinkedList<Variant> (); }
        public string? selected_variant_name { get; set; default = null; }

        construct {
            if (variants == null)
                variants = new Gee.LinkedList<Variant> ();
        }

        public virtual string usage_name {
            get { return title; }
        }

        public string get_usage_identifier () {
            if (this is Releases.SteamTinkerLaunch)
                return usage_name;

            if (runner is Tools.Basic) {
                var directory_name = get_effective_directory_name ();
                if (directory_name != "")
                    return directory_name;
            }

            return usage_name;
        }

        private Variant? get_selected_variant () {
            if (selected_variant_name == null || selected_variant_name == "" || variants == null)
                return null;

            foreach (var variant in variants) {
                if (variant.name == selected_variant_name)
                    return variant;
            }

            return null;
        }

        private string get_selected_variant_id () {
            var selected_variant = get_selected_variant ();
            if (selected_variant != null)
                return selected_variant.id;

            if (variants != null) {
                foreach (var variant in variants) {
                    if (variant.is_default)
                        return variant.id;
                }
            }

            return "";
        }

        private string get_variant_directory_suffix () {
            var selected_variant = get_selected_variant ();
            if (selected_variant == null || selected_variant.is_default)
                return "";

            var sanitized_variant_name = selected_variant.name.replace (" ", "_").replace ("/", "_");
            return "-%s".printf (sanitized_variant_name);
        }

        private string get_effective_directory_name () {
            var basic_runner = runner as Tools.Basic;
            if (basic_runner == null)
                return "";

            var directory_name = basic_runner.get_directory_name (title);
            if (directory_name == "")
                return "";

            var variant_suffix = get_variant_directory_suffix ();
            if (variant_suffix == "")
                return directory_name;

            return "%s%s".printf (directory_name, variant_suffix);
        }

        private void update_install_location () {
            install_location = "%s%s/%s".printf (
                runner.group.launcher.directory,
                runner.group.directory,
                get_effective_directory_name ()
            );
        }

        public void set_selected_variant (string? variant_name, ProtonPlus.Models.Assets.Asset? selected_asset = null) {
            selected_variant_name = variant_name;

            if (selected_asset != null)
                asset = selected_asset;

            if (!(runner is Tools.Basic))
                return;

            update_install_location ();
            refresh_state ();
        }

        private State _state;
        public State state {
            get {
                if (_state != State.BUSY_INSTALLING && _state != State.BUSY_REMOVING && _state != State.BUSY_UPDATING) {
                    var active_download = Utils.DownloadManager.instance.get_active_download (this);
                    if (active_download != null)
                        return active_download._state;
                }
                return _state;
            }
            set {
                _state = value;
            }
        }

        public Step step { get; set; }

        public virtual Json.Object to_json () {
            var obj = new Json.Object ();
            obj.set_string_member ("kind", "generic");
            obj.set_string_member ("title", title);
            obj.set_string_member ("description", description);
            obj.set_string_member ("release_date", release_date);
            obj.set_object_member ("asset", asset.to_json ());
            obj.set_string_member ("page_url", page_url);
            obj.set_string_member ("upstream_release_id", upstream_release_id);
            obj.set_string_member ("source_tag", source_tag);
            obj.set_int_member ("download_size", download_size);

            var variants_array = new Json.Array ();
            if (variants != null) {
                foreach (var variant in variants) {
                    var variant_obj = new Json.Object ();
                    variant_obj.set_string_member ("name", variant.name);
                    variant_obj.set_string_member ("format", variant.format);
                    variant_obj.set_boolean_member ("default", variant.is_default);
                    variant_obj.set_string_member ("download_url", variant.download_url ?? "");
                    variants_array.add_object_element (variant_obj);
                }
            }
            obj.set_array_member ("variants", variants_array);

            return obj;
        }

        public static Release ? from_json (Tool runner, Json.Object? obj) {
            if (obj == null) {
                return null;
            }

            if (!obj.has_member ("kind") || !obj.has_member ("title"))
                return null;
            string kind = obj.get_string_member_with_default ("kind", "");
            string title = obj.get_string_member_with_default ("title", "");
            string description = obj.get_string_member_with_default ("description", "");
            string release_date = obj.get_string_member_with_default ("release_date", "");
            if (!obj.has_member ("asset"))
                return null;

            var asset_node = obj.get_member ("asset");
            if (asset_node == null || asset_node.get_node_type () != Json.NodeType.OBJECT)
                return null;

            var asset = ProtonPlus.Models.Assets.Asset.from_json (asset_node.get_object ());
            if (asset == null)
                return null;
            string page_url = obj.get_string_member_with_default ("page_url", "");
            string upstream_release_id = obj.get_string_member_with_default ("upstream_release_id", "");
            string source_tag = obj.get_string_member_with_default ("source_tag", "");
            int64 download_size = obj.has_member ("download_size") ? obj.get_int_member ("download_size") : 0;

            if (kind == "" || title == "" || (upstream_release_id == "" && source_tag == ""))
                return null;

            Release? release = null;
            var basic_runner = runner as Tools.Basic;

            if (kind == "github-action") {
                if (basic_runner == null)
                    return null;

                string artifacts_url = obj.get_string_member_with_default ("artifacts_url", "");
                release = new Releases.GitHubAction (
                    basic_runner,
                    title,
                    release_date,
                    asset,
                    page_url,
                    artifacts_url,
                    upstream_release_id,
                    source_tag
                );
            } else if (kind == "latest") {
                if (basic_runner == null)
                    return null;

                var source_release_title = obj.get_string_member_with_default ("source_release_title", "");
                release = new Releases.Latest (
                    basic_runner,
                    title,
                    description,
                    release_date,
                    asset,
                    page_url,
                    source_release_title,
                    upstream_release_id,
                    source_tag
                );
            } else if (basic_runner != null) {
                // Default or generic
                release = new Release.github (
                    basic_runner,
                    title,
                    description,
                    release_date,
                    download_size,
                    asset,
                    page_url,
                    upstream_release_id,
                    source_tag
                );
            } else {
                return null;
            }

            if (release != null && basic_runner != null) {
                if (release.variants == null)
                    release.variants = new Gee.LinkedList<Variant> ();

                var variants_array = obj.get_array_member ("variants");
                if (variants_array != null) {
                    release.variants.clear ();
                    for (var i = 0; i < variants_array.get_length (); i++) {
                        var variant_obj = variants_array.get_object_element (i);
                        if (variant_obj == null)
                            continue;

                        string variant_name = variant_obj.get_string_member_with_default ("name", "");
                        if (variant_name == "")
                            continue;

                        string variant_format = variant_obj.get_string_member_with_default ("format", "");
                        bool variant_default = variant_obj.has_member ("default") && variant_obj.get_boolean_member ("default");
                        string variant_download_url = variant_obj.get_string_member_with_default ("download_url", "");

                        release.variants.add (new Variant (
                            variant_name,
                            variant_format,
                            variant_default,
                            basic_runner,
                            variant_download_url != "" ? variant_download_url : null
                        ));
                    }
                }
            }

            return release;
        }

        public Release.simple (Tools.Basic runner, string title, string install_location) {
            this.runner = runner;
            this.title = title;
            this.install_location = install_location;
            this.asset = new ProtonPlus.Models.Assets.Asset ("", "");
        }

        public Release.github (
            Tools.Basic runner,
            string title,
            string description,
            string release_date,
            int64 download_size,
            ProtonPlus.Models.Assets.Asset asset,
            string page_url,
            string upstream_release_id = "",
            string source_tag = ""
        ) {
            this.description = description;
            this.download_size = download_size;
            this.upstream_release_id = upstream_release_id;
            this.source_tag = source_tag;

            shared (runner, title, release_date, asset, page_url);
        }

        public Release.gitlab (
            Tools.Basic runner,
            string title,
            string description,
            string release_date,
            ProtonPlus.Models.Assets.Asset asset,
            string page_url,
            string upstream_release_id = "",
            string source_tag = ""
        ) {
            this.description = description;
            this.upstream_release_id = upstream_release_id;
            this.source_tag = source_tag;

            shared (runner, title, release_date, asset, page_url);
        }

        internal void shared (Tools.Basic runner, string title, string release_date, ProtonPlus.Models.Assets.Asset asset, string page_url) {
            this.runner = runner;
            this.title = title;
            this.displayed_title = title;
            if (this.description == null)
                this.description = "";
            this.release_date = release_date;
            this.asset = asset;
            this.page_url = page_url;

            update_install_location ();

            //this.variants = runner.variants;

            refresh_state ();
        }

        public virtual async ReturnCode install () {
            return yield install_internal (false);
        }

        public async ReturnCode install_replacement () {
            return yield install_internal (true);
        }

        private async ReturnCode install_internal (bool replace_existing) {
            if (state != State.BUSY_UPDATING && Utils.DownloadManager.instance.is_downloading (this))
                return ReturnCode.OPERATION_IN_PROGRESS;

            // A normal install must never turn into an implicit replacement.
            // Updates opt in explicitly after they have staged a replacement.
            if (!(this is Releases.SteamTinkerLaunch) && FileUtils.test (install_location, FileTest.EXISTS) && !replace_existing)
                return ReturnCode.RUNNER_ALREADY_INSTALLED;

            begin_operation ();
            is_finished = false;
            install_success = false;
            progress = null;
            speed_kbps = 0.0;
            seconds_remaining = -1.0;
            is_percent = false;

            var busy_updating = state == State.BUSY_UPDATING;

            if (!busy_updating)
                state = State.BUSY_INSTALLING;

            Utils.DownloadManager.instance.add_download (this);

            // Attempt the installation.
            replacement_backup_path = null;
            yield Utils.CacheManager.begin_cache_operation ();
            var code = yield _start_install (replace_existing);
            Utils.CacheManager.end_cache_operation ();
            runner.group.invalidate_installed_tool_index ();

            var success = code == ReturnCode.RUNNER_INSTALLED;

            this.is_finished = true;
            this.install_success = success;

            if (success)
                add_to_games_tab ();

            Utils.DownloadManager.instance.remove_download (this);
            Utils.DownloadManager.instance.add_to_history (this, success);

            if (!busy_updating)
                refresh_state (); // Force UI state refresh.

            return code;
        }

        protected string? get_archive_extension (string archive_path) {
            return Utils.ArchiveHelper.get_archive_extension (archive_path, true);
        }

        protected async ReturnCode complete_install_attempt (ReturnCode code, string operation_path, string staging_root) {
            // Both directories are owned by this attempt.  Never call remove()
            // here: it may point at a release that predates this operation.
            if (operation_path != "" && FileUtils.test (operation_path, FileTest.IS_DIR))
                yield Utils.Filesystem.delete_directory (operation_path);

            if (staging_root != "" && FileUtils.test (staging_root, FileTest.IS_DIR))
                yield Utils.Filesystem.delete_directory (staging_root);

            return code;
        }

        protected virtual async ReturnCode _start_install (bool replace_existing = false) {
            step = Step.DOWNLOADING;

            var extension = get_archive_extension (asset.name);
            if (extension == null)
                return ReturnCode.UNSUPPORTED_EXTENSION;

            var archive_cache_path = Path.build_filename (Globals.CACHE_PATH, "archives");
            if (!yield Utils.Filesystem.create_directory_async (archive_cache_path))
                return ReturnCode.FILESYSTEM_ERROR;

            var operation_path = Utils.Filesystem.create_temporary_directory (Globals.CACHE_PATH, ".protonplus-install-");
            if (operation_path == "")
                return ReturnCode.FILESYSTEM_ERROR;

            var staging_root = "";
            var archive_key = Checksum.compute_for_string (ChecksumType.SHA256, asset.download_url);
            var cache_archive_path = Path.build_filename (archive_cache_path, "%s%s".printf (archive_key, extension));
            var operation_archive_path = Path.build_filename (operation_path, "archive%s".printf (extension));

            if (!FileUtils.test (cache_archive_path, FileTest.IS_REGULAR)) {
                string? download_error;
                var download_valid = yield download_archive (
                    asset.download_url,
                    operation_archive_path,
                    out download_error
                );

                if (!download_valid) {
                    this.error_message = download_error;
                    return yield complete_install_attempt (ReturnCode.DOWNLOAD_FAILED, operation_path, staging_root);
                }

                var cached = yield Utils.Filesystem.move_file_atomic_if_absent (operation_archive_path, cache_archive_path);
                if (!cached && !FileUtils.test (cache_archive_path, FileTest.IS_REGULAR))
                    return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            // Extracting a private copy prevents a corrupted or in-progress
            // operation from ever writing into the shared archive cache.
            if (!yield Utils.Filesystem.copy_file (cache_archive_path, operation_archive_path))
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);

            // The archive copy cannot be interrupted, so honor a cancellation
            // that arrived while it was in progress before beginning extraction.
            if (canceled)
                return yield complete_install_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);

            step = Step.EXTRACTING;

            string? source_path = yield Utils.Filesystem.extract (operation_path, "archive", extension, operation_cancellable);

            if (source_path == null || source_path == "") {
                if (!canceled)
                    error_message = _("Extraction failed");
                return yield complete_install_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);
            }

            source_path = yield _after_extraction (source_path, operation_path);

            if (source_path == null || source_path == "") {
                if (!canceled && error_message == null)
                    error_message = _("Extraction failed");
                return yield complete_install_attempt (ReturnCode.EXTRACTION_FAILED, operation_path, staging_root);
            }

            step = Step.MOVING;

            var install_parent = Path.get_dirname (install_location);
            if (!yield Utils.Filesystem.create_directory_async (install_parent))
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);

            staging_root = Utils.Filesystem.create_temporary_directory (install_parent, ".protonplus-stage-");
            if (staging_root == "")
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);

            var staged_install_path = Path.build_filename (staging_root, "installation");
            if (!yield Utils.Filesystem.move_directory (source_path, staged_install_path)) {
                error_message = _("Moving failed");
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            if (!yield _after_staging_install (staged_install_path))
                return yield complete_install_attempt (ReturnCode.INVALID_DATA, operation_path, staging_root);

            persist_runner_install_metadata (staged_install_path);

            if (FileUtils.test (install_location, FileTest.EXISTS)) {
                if (!replace_existing)
                    return yield complete_install_attempt (ReturnCode.RUNNER_ALREADY_INSTALLED, operation_path, staging_root);

                var backup_path = Path.build_filename (install_parent, ".protonplus-previous-%s".printf (Path.get_basename (staging_root)));
                if (!yield Utils.Filesystem.move_directory_atomic (install_location, backup_path))
                    return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);

                if (!yield promote_staged_installation (staged_install_path)) {
                    yield Utils.Filesystem.move_directory_atomic (backup_path, install_location);
                    return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
                }

                replacement_backup_path = backup_path;
            } else if (!yield promote_staged_installation (staged_install_path)) {
                error_message = _("Moving failed");
                return yield complete_install_attempt (ReturnCode.FILESYSTEM_ERROR, operation_path, staging_root);
            }

            destination_path = install_location;

            return yield complete_install_attempt (ReturnCode.RUNNER_INSTALLED, operation_path, staging_root);
        }

        // Keeping archive acquisition behind the release lets installer tests
        // provide a local fixture while production releases continue to use the
        // normal cancellable network path.
        protected virtual async bool download_archive (string url, string path, out string? error_message) {
            return yield Utils.Web.download (
                url,
                path,
                operation_cancellable,
                on_download_progress,
                out error_message
            );
        }

        // The final promotion is deliberately separate from moving the current
        // installation to its backup.  A failed promotion must restore that
        // backup without ever exposing a partly copied installation.
        protected virtual async bool promote_staged_installation (string staged_install_path) {
            return yield Utils.Filesystem.move_directory_atomic (staged_install_path, install_location);
        }

        protected virtual string get_legacy_metadata_tag () {
            return source_tag != "" ? source_tag : title;
        }

        private void persist_runner_install_metadata (string path) {
            var basic_runner = runner as Tools.Basic;
            if (basic_runner == null)
                return;

            var metadata = Utils.Metadata.load (path);
            metadata.runner_endpoint = basic_runner.endpoint;
            metadata.runner_title = basic_runner.title;
            metadata.tag = get_legacy_metadata_tag ();
            metadata.provider_id = basic_runner.provider_id;
            metadata.tool_id = basic_runner.id;
            metadata.launcher_id = basic_runner.group.launcher.instance_id;
            metadata.variant_id = get_selected_variant_id ();
            metadata.release_id = upstream_release_id;
            metadata.save (path);
        }

        protected virtual async string? _after_extraction (string source_path, string extract_path) {
            return source_path;
        }

        protected virtual async bool _after_staging_install (string staged_install_path) {
            return true;
        }

        protected async string? extract_nested_archive (string source_path, string extract_path) {
            var extension = get_archive_extension (source_path);
            if (extension == null)
                return "";

            var archive_name = Path.get_basename (source_path);
            archive_name = archive_name.substring (0, archive_name.length - extension.length);
            return yield Utils.Filesystem.extract (extract_path, archive_name, extension, operation_cancellable);
        }

        public virtual async ReturnCode remove (bool notify_removal = false) {
            var busy_updating_or_installing = state == State.BUSY_UPDATING || state == State.BUSY_INSTALLING;

            if (!busy_updating_or_installing) {
                canceled = false;
                state = State.BUSY_REMOVING;
            }

            // Attempt the removal.
            var code = yield _start_remove ();
            runner.group.invalidate_installed_tool_index ();

            var success = code == ReturnCode.RUNNER_REMOVED;

            if (!busy_updating_or_installing)
                refresh_state (); // Force UI state refresh.

            if (success) {
                remove_from_games_tab ();
                if (notify_removal)
                    Utils.DownloadManager.instance.tool_removed (this);
            }

            return code;
        }

        protected virtual async ReturnCode _start_remove () {
            step = Step.REMOVING;

            if (!FileUtils.test (install_location, FileTest.IS_DIR))
                return ReturnCode.RUNNER_REMOVED;

            var success = yield Utils.Filesystem.delete_directory (install_location);

            return success ? ReturnCode.RUNNER_REMOVED : ReturnCode.FILESYSTEM_ERROR;
        }

        public virtual async ReturnCode update () {
            if (Utils.DownloadManager.instance.is_downloading (this))
                return ReturnCode.OPERATION_IN_PROGRESS;

            // Unlike SteamTinkerLaunch, basic releases are installed directly
            // at install_location. Avoid starting an update if that directory
            // was deleted while the application was open.
            if (runner is Tools.Basic && !FileUtils.test (install_location, FileTest.IS_DIR)) {
                refresh_state ();
                return ReturnCode.RUNNER_NOT_INSTALLED;
            }

            begin_operation ();

            state = State.BUSY_UPDATING;

            Utils.DownloadManager.instance.add_download (this);

            var update_code = yield _start_update ();

            Utils.DownloadManager.instance.remove_download (this);

            refresh_state ();

            return update_code;
        }

        protected virtual async ReturnCode _start_update () { return ReturnCode.UNSUPPORTED_OPERATION; }

        private void begin_operation () {
            _canceled = false;
            operation_cancellable = new Cancellable ();
            notify_property ("canceled");
        }

        protected virtual void refresh_state () {
            step = Step.NOTHING;

            var directory_name = get_effective_directory_name ();
            var directory_name_valid = directory_name != "";
            var install_directory_valid = FileUtils.test (install_location, FileTest.IS_DIR);

            if (title.contains ("Latest")) {
                var backup_directory_name = "%s Backup".printf (directory_name);
                var backup_directory_path = "%s%s/%s".printf (
                    runner.group.launcher.directory,
                    runner.group.directory,
                    backup_directory_name
                );
                var backup_directory_valid = FileUtils.test (backup_directory_path, FileTest.IS_DIR);

                state = (directory_name_valid && (install_directory_valid || backup_directory_valid)) ? State.UP_TO_DATE : State.NOT_INSTALLED;
            } else {
                state = (directory_name_valid && install_directory_valid) ? State.UP_TO_DATE : State.NOT_INSTALLED;
            }
        }

        protected void on_download_progress (bool is_percent, int64 progress, double speed_kbps, double? remaining_seconds) {
            this.is_percent = is_percent;
            this.progress = is_percent ? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress);
            this.speed_kbps = speed_kbps;
            this.seconds_remaining = remaining_seconds ?? -1.0;
            progress_updated ();
            Utils.DownloadManager.instance.progress_updated (this);
        }

        void add_to_games_tab () {
            if (runner.group.launcher.title != "Steam")
                return;

            var simple_runner = new Tools.Simple.from_path (install_location);
            var steam_launcher = runner.group.launcher as Launchers.Steam;
            if (steam_launcher != null)
                steam_launcher.register_compatibility_tool (simple_runner);
        }

        void remove_from_games_tab () {
            var steam_launcher = runner.group.launcher as Launchers.Steam;
            if (steam_launcher != null)
                steam_launcher.unregister_compatibility_tool_by_path (install_location);
        }
    }
}
