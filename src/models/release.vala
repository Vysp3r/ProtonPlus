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
        public string download_url { get; set; }
        public string page_url { get; set; }
        public bool canceled { get; set; }
        public string progress { get; set; }
        public double speed_kbps { get; set; }
        public double seconds_remaining { get; set; }
        public bool is_percent { get; set; }
        public bool is_finished { get; set; default = false; }
        public bool install_success { get; set; default = false; }
        public string? error_message { get; set; }
        public string install_location { get; set; }
        public int64 download_size { get; set; }
        protected string destination_path { get; set; }
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

        private string get_variant_directory_suffix () {
            var selected_variant = get_selected_variant ();
            if (selected_variant == null || selected_variant.is_default)
                return "";

            var sanitized_variant_name = selected_variant.name.replace (" ", "_").replace ("/", "_");
            return "-%s".printf (sanitized_variant_name);
        }

        private string get_effective_directory_name () {
            var directory_name = ((Tools.Basic) runner).get_directory_name (title);
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

        public void set_selected_variant (string? variant_name) {
            selected_variant_name = variant_name;
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
            obj.set_string_member ("download_url", download_url);
            obj.set_string_member ("page_url", page_url);
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

            if (!obj.has_member ("kind") || !obj.has_member ("title"))return null;
            string kind = obj.get_string_member_with_default ("kind", "");
            string title = obj.get_string_member_with_default ("title", "");
            string description = obj.get_string_member_with_default ("description", "");
            string release_date = obj.get_string_member_with_default ("release_date", "");
            string download_url = obj.get_string_member_with_default ("download_url", "");
            string page_url = obj.get_string_member_with_default ("page_url", "");
            int64 download_size = obj.has_member ("download_size") ? obj.get_int_member ("download_size") : 0;

            if (kind == "" || title == "")
                return null;

            Release? release = null;

            if (kind == "github-action") {
                string artifacts_url = obj.get_string_member_with_default ("artifacts_url", "");
                release = new Releases.GitHubAction (runner as Tools.Basic, title, release_date, download_url, page_url, artifacts_url);
            } else if (kind == "latest") {
                release = new Releases.Latest (runner as Tools.Basic, title, description, release_date, download_url, page_url);
            } else if (runner is Tools.Basic) {
                // Default or generic
                release = new Release.github (runner as Tools.Basic, title, description, release_date, download_size, download_url, page_url);
            } else {
                return null;
            }

            var basic_runner = runner as Tools.Basic;
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
        }

        public Release.github (Tools.Basic runner, string title, string description, string release_date, int64 download_size, string download_url, string page_url) {
            this.description = description;
            this.download_size = download_size;

            shared (runner, title, release_date, download_url, page_url);
        }

        public Release.gitlab (Tools.Basic runner, string title, string description, string release_date, string download_url, string page_url) {
            this.description = description;

            shared (runner, title, release_date, download_url, page_url);
        }

        internal void shared (Tools.Basic runner, string title, string release_date, string download_url, string page_url) {
            this.runner = runner;
            this.title = title;
            this.displayed_title = title;
            if (this.description == null)
                this.description = "";
            this.release_date = release_date;
            this.download_url = download_url;
            this.page_url = page_url;

            update_install_location ();

            //this.variants = runner.variants;

            refresh_state ();
        }

        public virtual async ReturnCode install () {
            if (state != State.BUSY_UPDATING && Utils.DownloadManager.instance.is_downloading (this))
                return ReturnCode.UNKNOWN_ERROR;

            canceled = false;
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
            var code = yield _start_install ();

            var success = code == ReturnCode.RUNNER_INSTALLED;

            this.is_finished = true;
            this.install_success = success;

            if (success)
                add_to_games_tab ();

            Utils.DownloadManager.instance.remove_download (this);
            Utils.DownloadManager.instance.add_to_history (this, success);

            if (!success)
                yield remove (); // Refreshes install state too.

            if (!busy_updating)
                refresh_state (); // Force UI state refresh.

            return code;
        }

        protected virtual async ReturnCode _start_install () {
            step = Step.DOWNLOADING;

            string extension = ".tar.gz";
            if (download_url.contains (".zip")) {
                extension = ".zip";
            } else if (download_url.contains (".tar.xz")) {
                extension = ".tar.xz";
            } else if (!download_url.contains (".tar")) {
                return ReturnCode.UNSUPPORTED_EXTENSION;
            }

            string download_path = "%s/%s%s".printf (Globals.CACHE_PATH, title, extension);

            var used_cached_archive = FileUtils.test (download_path, FileTest.EXISTS);

            if (!FileUtils.test (download_path, FileTest.EXISTS)) {
                string? download_error;
                var download_valid = yield Utils.Web.Download (download_url, download_path, () => canceled, on_download_progress, out download_error);

                if (!download_valid) {
                    this.error_message = download_error;
                    return ReturnCode.UNKNOWN_ERROR;
                }
            }

            step = Step.EXTRACTING;

            string extract_path = "%s/".printf (Globals.CACHE_PATH);

            string source_path = yield Utils.Filesystem.extract (extract_path, title, extension, () => canceled);

            // Stale/incomplete cache files can survive crashes and fail extraction.
            // If we used a cached archive, retry once with a fresh download.
            if (source_path == "" && !canceled && used_cached_archive) {
                Utils.Filesystem.delete_file (download_path);

                step = Step.DOWNLOADING;

                string? download_error;
                var download_valid = yield Utils.Web.Download (download_url, download_path, () => canceled, on_download_progress, out download_error);

                if (!download_valid) {
                    this.error_message = download_error;
                    return ReturnCode.UNKNOWN_ERROR;
                }

                step = Step.EXTRACTING;
                source_path = yield Utils.Filesystem.extract (extract_path, title, extension, () => canceled);
            }

            if (source_path == "") {
                if (!canceled)
                    error_message = _("Extraction failed");
                return ReturnCode.EXTRACTION_FAILED;
            }

            source_path = yield _after_extraction (source_path, extract_path);

            if (source_path == "") {
                if (!canceled && error_message == null)
                    error_message = _("Extraction failed");
                return ReturnCode.EXTRACTION_FAILED;
            }

            step = Step.MOVING;

            destination_path = "%s/".printf (install_location);

            var renaming_valid = yield Utils.Filesystem.move_directory (source_path, destination_path);

            if (!renaming_valid) {
                error_message = _("Moving failed");
                return ReturnCode.UNKNOWN_ERROR;
            }

            return ReturnCode.RUNNER_INSTALLED;
        }

        protected virtual async string _after_extraction (string source_path, string extract_path) {
            return source_path;
        }

        public virtual async ReturnCode remove () {
            var busy_updating_or_installing = state == State.BUSY_UPDATING || state == State.BUSY_INSTALLING;

            if (!busy_updating_or_installing) {
                canceled = false;
                state = State.BUSY_REMOVING;
            }

            // Attempt the removal.
            var code = yield _start_remove ();

            var success = code == ReturnCode.RUNNER_REMOVED;

            if (!busy_updating_or_installing)
                refresh_state (); // Force UI state refresh.

            if (success) {
                remove_from_games_tab ();
                Utils.DownloadManager.instance.tool_removed (this);
            }

            return code;
        }

        protected virtual async ReturnCode _start_remove () {
            step = Step.REMOVING;

            var success = yield Utils.Filesystem.delete_directory (install_location);

            return success ? ReturnCode.RUNNER_REMOVED : ReturnCode.UNKNOWN_ERROR;
        }

        public virtual async ReturnCode update () {
            if (Utils.DownloadManager.instance.is_downloading (this))
                return ReturnCode.UNKNOWN_ERROR;

            canceled = false;

            state = State.BUSY_UPDATING;

            Utils.DownloadManager.instance.add_download (this);

            var update_code = yield _start_update ();

            Utils.DownloadManager.instance.remove_download (this);

            refresh_state ();

            return update_code;
        }

        protected virtual async ReturnCode _start_update () { return ReturnCode.UNKNOWN_ERROR; }

        protected virtual void refresh_state () {
            step = Step.NOTHING;

            var directory_name = get_effective_directory_name ();
            var directory_name_valid = directory_name != "";
            var install_directory_valid = FileUtils.test (install_location, FileTest.IS_DIR);

            if (title.contains ("Latest")) {
                var backup_directory_name = "%s Backup".printf (directory_name);
                var backup_directory_valid = FileUtils.test ("%s%s/%s".printf (runner.group.launcher.directory, runner.group.directory, backup_directory_name), FileTest.IS_DIR);

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
            Utils.DownloadManager.instance.progress_updated (this);
        }

        void add_to_games_tab () {
            if (runner.group.launcher.title != "Steam")
                return;

            var simple_runner = new Tools.Simple.from_path (install_location);

            runner.group.launcher.compatibility_tools.add (simple_runner);
        }

        void remove_from_games_tab () {
            var tool = runner.group.launcher.compatibility_tools.first_match ((tool) => {
                return tool.path == install_location;
            });

            if (tool != null)
                runner.group.launcher.compatibility_tools.remove (tool);
        }
    }
}
