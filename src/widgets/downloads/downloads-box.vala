using Gee;

namespace ProtonPlus.Widgets {
	public class DownloadsBox : Gtk.Box {
		private Gtk.ListBox list_box;
		private Gtk.Label empty_label;
		private Adw.Clamp clamp;
		private Gtk.ScrolledWindow scrolled_window;

		public DownloadsBox() {
			Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
			set_vexpand(true);

			empty_label = new Gtk.Label(_("No active downloads."));
			empty_label.add_css_class("title-2");
			empty_label.vexpand = true;

			list_box = new Gtk.ListBox();
			list_box.selection_mode = Gtk.SelectionMode.NONE;
			list_box.add_css_class("boxed-list");
			list_box.set_margin_top(15);
			list_box.set_margin_bottom(15);
			list_box.set_margin_start(15);
			list_box.set_margin_end(15);

			clamp = new Adw.Clamp();
			clamp.maximum_size = 975;
			clamp.child = list_box;

			scrolled_window = new Gtk.ScrolledWindow();
			scrolled_window.child = clamp;
			scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.vexpand = true;

			append(scrolled_window);
			append(empty_label);

			Models.DownloadManager.instance.download_added.connect(on_download_added);
			Models.DownloadManager.instance.download_removed.connect(on_download_removed);

			update_visibility();

			foreach (var release in Models.DownloadManager.instance.active_downloads) {
				add_download_row(release);
			}
		}

		private void on_download_added(Models.Release<Models.Parameters> release) {
			add_download_row(release);
			update_visibility();
		}

		private void on_download_removed(Models.Release<Models.Parameters> release) {
			var child = list_box.get_first_child();
			while (child != null) {
				if (child is DownloadRow && ((DownloadRow)child).release == release) {
					list_box.remove(child);
					break;
				}
				child = child.get_next_sibling();
			}
			update_visibility();
		}

		private void add_download_row(Models.Release<Models.Parameters> release) {
			var row = new DownloadRow(release);
			list_box.append(row);
		}

		private void update_visibility() {
			bool has_downloads = Models.DownloadManager.instance.active_downloads.size > 0;
			scrolled_window.set_visible(has_downloads);
			empty_label.set_visible(!has_downloads);
		}
	}
}
