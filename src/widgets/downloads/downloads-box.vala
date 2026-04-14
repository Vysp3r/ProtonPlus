namespace ProtonPlus.Widgets {
	public class DownloadsBox : Gtk.Box {
		private Gtk.ListBox in_progress_list_box;
		private Gtk.ListBox completed_list_box;
		private Gtk.Box in_progress_box;
		private Gtk.Box completed_box;
		private Adw.StatusPage status_page;
		private Adw.Clamp clamp;
		private Gtk.ScrolledWindow scrolled_window;
		private Gtk.Box completed_header_box;
		private Gtk.Button clear_button;

		public DownloadsBox() {
			Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
			set_vexpand(true);

			status_page = new Adw.StatusPage();
			status_page.set_title(_("No active downloads"));
			status_page.set_description(_("Your downloads will appear here."));
			status_page.set_icon_name("download-symbolic");
			status_page.vexpand = true;

			var in_progress_label = new Gtk.Label(_("In-Progress"));
			in_progress_label.add_css_class("heading");
			in_progress_label.set_halign(Gtk.Align.START);
			in_progress_label.set_margin_start(12);

			in_progress_list_box = new Gtk.ListBox();
			in_progress_list_box.selection_mode = Gtk.SelectionMode.NONE;
			in_progress_list_box.add_css_class("boxed-list");

			in_progress_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
			in_progress_box.append(in_progress_label);
			in_progress_box.append(in_progress_list_box);

			var completed_label = new Gtk.Label(_("Completed"));
			completed_label.add_css_class("heading");
			completed_label.set_halign(Gtk.Align.START);
			completed_label.set_margin_start(12);

			var spacer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			spacer.set_hexpand(true);

			clear_button = new Gtk.Button.from_icon_name("edit-clear-all-symbolic");
			clear_button.add_css_class("flat");
			clear_button.add_css_class("circular");
			clear_button.set_tooltip_text(_("Clear History"));
			clear_button.clicked.connect(on_clear_clicked);

			completed_header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
			completed_header_box.append(completed_label);
			completed_header_box.append(spacer);
			completed_header_box.append(clear_button);

			completed_list_box = new Gtk.ListBox();
			completed_list_box.selection_mode = Gtk.SelectionMode.NONE;
			completed_list_box.add_css_class("boxed-list");

			completed_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
			completed_box.append(completed_header_box);
			completed_box.append(completed_list_box);

			var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
			content_box.append(in_progress_box);
			content_box.append(completed_box);

			clamp = new Adw.Clamp();
			clamp.maximum_size = 975;
			clamp.child = content_box;

			scrolled_window = new Gtk.ScrolledWindow();
			scrolled_window.child = clamp;
			scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.vexpand = true;

			append(scrolled_window);
			append(status_page);

			Models.DownloadManager.instance.download_added.connect(on_download_added);
			Models.DownloadManager.instance.download_removed.connect(on_download_removed);
			Models.DownloadManager.instance.download_finished.connect(on_download_finished);

			update_visibility();

			foreach (var release in Models.DownloadManager.instance.active_downloads) {
				add_download_row(release, in_progress_list_box);
			}

			foreach (var release in Models.DownloadManager.instance.history) {
				add_download_row(release, completed_list_box);
			}
		}

		private void on_download_added(Models.BaseRelease release) {
			var child = completed_list_box.get_first_child();
			while (child != null) {
				var next = child.get_next_sibling();
				if (child is DownloadRow && ((DownloadRow)child).release.title == release.title) {
					completed_list_box.remove(child);
				}
				child = next;
			}

			add_download_row(release, in_progress_list_box);
			update_visibility();
		}

		private void on_download_removed(Models.BaseRelease release) {
			update_visibility();
		}

		private void on_download_finished(Models.BaseRelease release, bool success) {
			var child = in_progress_list_box.get_first_child();
			while (child != null) {
				if (child is DownloadRow && ((DownloadRow)child).release == release) {
					in_progress_list_box.remove(child);
					break;
				}
				child = child.get_next_sibling();
			}

			add_download_row(release, completed_list_box);
			update_visibility();
		}

		private void on_clear_clicked() {
			Models.DownloadManager.instance.clear_history();
			var child = completed_list_box.get_first_child();
			while (child != null) {
				var next = child.get_next_sibling();
				completed_list_box.remove(child);
				child = next;
			}
			update_visibility();
		}

		private void add_download_row(Models.BaseRelease release, Gtk.ListBox list_box) {
			var row = new DownloadRow(release);
			list_box.prepend(row);
		}

		private void update_visibility() {
			bool has_downloads = Models.DownloadManager.instance.active_downloads.size > 0 || Models.DownloadManager.instance.history.size > 0;
			bool has_active = Models.DownloadManager.instance.active_downloads.size > 0;
			bool has_history = Models.DownloadManager.instance.history.size > 0;

			completed_header_box.set_visible(has_downloads);
			scrolled_window.set_visible(has_downloads);
			status_page.set_visible(!has_downloads);
			clear_button.set_visible(has_history);

			in_progress_box.set_visible(has_active);
			completed_box.set_visible(has_history);
		}
	}
}
