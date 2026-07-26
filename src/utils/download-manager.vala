namespace ProtonPlus.Utils {
    /// Manages active downloads and download history persistence.
    public class DownloadManager : GLib.Object {
        private static DownloadManager? _instance = null;
        public static DownloadManager instance {
            get {
                if (_instance == null) {
                    _instance = new DownloadManager ();
                }
                return _instance;
            }
        }

        public Gee.LinkedList<Services.InstallJob> active_downloads { get; private set; }

        public int64 speed_limit_bps { get; set; default = 0; }

        /// Checks whether this target-bound operation is currently active.
        public bool is_downloading (Services.InstallJob job) {
            return get_active_download (job) != null;
        }

        /// Stable target identity prevents collisions between equal titles.
        public Services.InstallJob? get_active_download (Services.InstallJob job) {
            foreach (var active_download in active_downloads) {
                if (active_download.operation_id == job.operation_id) {
                    return active_download;
                }
            }
            return null;
        }

        public bool has_active_installation_at (string install_location) {
            foreach (var active_download in active_downloads) {
                if (active_download.install_location == install_location)
                    return true;
            }
            return false;
        }

        /// Signals emitted when download state changes.
        public signal void download_added (Services.InstallJob job);
        public signal void download_removed (Services.InstallJob job);
        public signal void download_finished (Services.InstallJob job, bool success);
        public signal void progress_updated (Services.InstallJob job);
        public signal void tool_updated (Services.InstallJob job, bool updated);
        public signal void tool_removed (Services.InstallJob job);
        public signal void speed_limit_changed (int64 new_limit);

        private DownloadManager () {
            active_downloads = new Gee.LinkedList<Services.InstallJob> ();
            this.notify["speed-limit-bps"].connect (() => {
                speed_limit_changed (this.speed_limit_bps);
            });
        }

        public void add_download (Services.InstallJob job) {
            if (!is_downloading (job)) {
                active_downloads.add (job);
                download_added (job);
            }
        }

        public void remove_download (Services.InstallJob job) {
            if (active_downloads.contains (job)) {
                active_downloads.remove (job);
                download_removed (job);
            }
        }

        public void add_to_history (Services.InstallJob job, bool success) {
            download_finished (job, success);
        }

        public async void async_sleep (uint milliseconds) {
            if (milliseconds == 0)
                return;

            Timeout.add (milliseconds, () => {
                async_sleep.callback ();
                return Source.REMOVE;
            });
            yield;
        }

    }
}
