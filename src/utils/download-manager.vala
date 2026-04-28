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

        public Gee.LinkedList<Models.Release> active_downloads { get; private set; }

        /// Checks if a release is currently being downloaded.
        public bool is_downloading (Models.Release release) {
            return get_active_download (release) != null;
        }

        /// Returns the active download if it matches the given release, otherwise null.
        public Models.Release? get_active_download (Models.Release release) {
            foreach (var active_download in active_downloads) {
                if (active_download.download_url == release.download_url && active_download.title == release.title) {
                    return active_download;
                }
            }
            return null;
        }

        /// Signals emitted when download state changes.
        public signal void download_added (Models.Release release);
        public signal void download_removed (Models.Release release);
        public signal void download_finished (Models.Release release, bool success);
        public signal void tool_updated (Models.Release release, bool updated);
        public signal void tool_removed (Models.Release release);

        private DownloadManager () {
            active_downloads = new Gee.LinkedList<Models.Release> ();
        }

        public void add_download (Models.Release release) {
            if (!is_downloading (release)) {
                active_downloads.add (release);
                download_added (release);
            }
        }

        public void remove_download (Models.Release release) {
            if (active_downloads.contains (release)) {
                active_downloads.remove (release);
                download_removed (release);
            }
        }

        public void add_to_history (Models.Release release, bool success) {
            download_finished (release, success);
        }

    }
}
