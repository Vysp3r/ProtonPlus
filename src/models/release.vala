namespace ProtonPlus.Models {
    public class Release : Object {
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

        private State _state;
        public State state {
            get {
                if (_state != State.BUSY_INSTALLING && _state != State.BUSY_REMOVING && _state != State.BUSY_UPDATING) {
                    var active_download = Utils.DownloadManager.instance.get_active_download (this);
                    if (active_download != null)
                    return active_download.state;
                }
                return _state;
            }
            set {
                _state = value;
            }
        }

        public Step step { get; set; }


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
            this.description = description;
            this.release_date = release_date;
            this.download_url = download_url;
            this.page_url = page_url;

            install_location = runner.group.launcher.directory + runner.group.directory + "/" + runner.get_directory_name (title);

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

            if (!download_url.contains (".tar"))
            return ReturnCode.UNKNOWN_ERROR;

            string download_path = "%s/%s.tar.gz".printf (Globals.CACHE_PATH, title);

            if (!FileUtils.test (download_path, FileTest.EXISTS)) {
                string? download_error;
                var download_valid = yield Utils.Web.Download (download_url, download_path, () => canceled, (is_percent, progress, speed_kbps, seconds_remaining) => {
                    this.is_percent = is_percent;
                    this.progress = is_percent ? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress);
                    this.speed_kbps = speed_kbps;
                    this.seconds_remaining = seconds_remaining;
                }, out download_error);

                if (!download_valid) {
                    this.error_message = download_error;
                    return ReturnCode.UNKNOWN_ERROR;
                }
            }

            step = Step.EXTRACTING;

            string extract_path = "%s/".printf (Globals.CACHE_PATH);

            string source_path = yield Utils.Filesystem.extract (extract_path, title, ".tar.gz", () => canceled);
            if (source_path == "") {
                if (!canceled)
                error_message = _ ("Extraction failed");
                return ReturnCode.UNKNOWN_ERROR;
            }

            step = Step.MOVING;

            var runner = this.runner as Tools.Basic;

            destination_path = "%s%s/%s/".printf (runner.group.launcher.directory, runner.group.directory, runner.get_directory_name (title)) ;

            var renaming_valid = yield Utils.Filesystem.move_directory (source_path, destination_path);
            if (!renaming_valid) {
                error_message = _ ("Moving failed");
                return ReturnCode.UNKNOWN_ERROR;
            }

            return ReturnCode.RUNNER_INSTALLED;
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

            var directory_name = ((Tools.Basic)runner).get_directory_name (title);
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

        void add_to_games_tab () {
            if (runner.group.launcher.title != "Steam")
            return;

            var simple_runner = new Tools.Simple.from_path(install_location);

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
