namespace ProtonPlus.Models {
    public abstract class BaseRelease : Object {
        public Runner runner { get; set; }
        public string title { get; set; }
        public string displayed_title { get; set; }
        public string description { get; set; }
        public string release_date { get; set; }
        public string download_url { get; set; }
        public string page_url { get; set; }
        public bool canceled { get; set; }
        public string progress { get; set; }
        public double speed_kbps { get; set; }
        public double? seconds_remaining { get; set; }
        public bool is_percent { get; set; }
        public bool is_finished { get; set; default = false; }
        public bool install_success { get; set; default = false; }

        private State _state;
        public State state {
            get {
                if (_state != State.BUSY_INSTALLING && _state != State.BUSY_REMOVING && _state != State.BUSY_UPDATING) {
                    var active_download = DownloadManager.instance.get_active_download (this);
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

        public abstract async bool install ();
        protected abstract async bool _start_install ();
        public abstract async bool remove (Parameters parameters);
        protected abstract void refresh_state ();
    }

    public abstract class Release<R> : BaseRelease {
        public override async bool install () {
            if (state != State.BUSY_UPDATING && DownloadManager.instance.is_downloading (this))
            return false;

            canceled = false;
            is_finished = false;
            install_success = false;
            progress = null;
            speed_kbps = 0.0;
            seconds_remaining = null;
            is_percent = false;

            var busy_updating = state == State.BUSY_UPDATING;

            if (!busy_updating)
            state = State.BUSY_INSTALLING;

            DownloadManager.instance.add_download (this);

            // Attempt the installation.
            var success = yield _start_install ();

            this.is_finished = true;
            this.install_success = success;

            DownloadManager.instance.remove_download (this);
            DownloadManager.instance.add_to_history (this, success);

            if (!success)
            yield remove (new Models.Parameters ()); // Refreshes install state too.

            if (!busy_updating)
            refresh_state (); // Force UI state refresh.

            return success;
        }

        public override async bool remove (Parameters parameters) {
            var busy_updating_or_installing = state == State.BUSY_UPDATING || state == State.BUSY_INSTALLING;

            if (!busy_updating_or_installing) {
                canceled = false;
                state = State.BUSY_REMOVING;
            }

            // Attempt the removal.
            var remove_success = yield _start_remove ((R) parameters);

            if (!busy_updating_or_installing)
            refresh_state (); // Force UI state refresh.

            return remove_success;
        }

        protected abstract async bool _start_remove (R parameters);
    }
}
