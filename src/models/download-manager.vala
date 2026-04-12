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

		public ArrayList<Release<Parameters>> active_downloads { get; private set; }
		
		public bool is_downloading (Release<Parameters> release) {
			foreach (var active_download in active_downloads) {
				if (active_download.download_url == release.download_url && active_download.title == release.title) {
					return true;
				}
			}
			return false;
		}

		public signal void download_added (Release<Parameters> release);
		public signal void download_removed (Release<Parameters> release);

		private DownloadManager () {
			active_downloads = new ArrayList<Release<Parameters>> ();
		}

		public void add_download (Release<Parameters> release) {
			if (!is_downloading (release)) {
				active_downloads.add (release);
				download_added (release);
			}
		}

		public void remove_download (Release<Parameters> release) {
			if (active_downloads.contains (release)) {
				active_downloads.remove (release);
				download_removed (release);
			}
		}
	}
}
