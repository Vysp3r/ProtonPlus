using Gee;

namespace ProtonPlus.Models {
	public class DownloadManager : Object {
		private static DownloadManager _instance;
		public static DownloadManager instance {
			get {
				if (_instance == null) {
					_instance = new DownloadManager ();
				}
				return _instance;
			}
		}

		public ArrayList<BaseRelease> active_downloads { get; private set; }
		
		public bool is_downloading (BaseRelease release) {
			return get_active_download (release) != null;
		}

		public BaseRelease? get_active_download (BaseRelease release) {
			foreach (var active_download in active_downloads) {
				if (active_download.download_url == release.download_url && active_download.title == release.title) {
					return active_download;
				}
			}
			return null;
		}

		public signal void download_added (BaseRelease release);
		public signal void download_removed (BaseRelease release);

		private DownloadManager () {
			active_downloads = new ArrayList<BaseRelease> ();
		}

		public void add_download (BaseRelease release) {
			if (!is_downloading (release)) {
				active_downloads.add (release);
				download_added (release);
			}
		}

		public void remove_download (BaseRelease release) {
			if (active_downloads.contains (release)) {
				active_downloads.remove (release);
				download_removed (release);
			}
		}
	}
}
