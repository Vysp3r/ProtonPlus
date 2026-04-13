namespace ProtonPlus.Widgets {
	public class BasicRow : ReleaseRow {
		Models.Releases.Basic release { get; set; }

		public BasicRow (Models.Releases.Basic release) {
			this.release = release;

			var time = new DateTime.from_iso8601 (release.release_date, new GLib.TimeZone.local ());

			this.set_subtitle (time.format ("%c"));

			if (release.description == null || release.page_url == null)
				input_box.remove (info_button);

			if (release.title.contains ("Latest")) {
				set_subtitle (_("This version will get automatically updated when there's an update available each time your launch the application if automatic updates is enabled"));
			} else {
				input_box.remove (update_button);
			}

			release.notify["displayed-title"].connect (release_displayed_title_changed);

			release_displayed_title_changed ();

			release.notify["state"].connect (release_state_changed);
			Application.window.notify["updating"].connect (release_state_changed);

			release_state_changed ();

			Models.DownloadManager.instance.download_added.connect (on_download_status_changed);
			Models.DownloadManager.instance.download_removed.connect (on_download_status_changed);
		}

		private void on_download_status_changed (Models.BaseRelease added_release) {
			if (added_release.download_url == release.download_url && added_release.title == release.title) {
				release_state_changed ();
			}
		}

		protected override void update_button_clicked () {
			Application.window.check_for_updates.begin (release.runner as Models.Runners.Basic);
		}

		protected override void open_button_clicked () {
			Utils.System.open_uri ("file://%s".printf (release.install_location));
		}

		protected override void install_button_clicked () {
			release.install.begin ((obj, res) => {
				var success = release.install.end (res);
				if (!success && !release.canceled) {
					var dialog = new ErrorDialog (_("Couldn't install %s").printf (release.title), _("Please report this issue on GitHub."));
					dialog.present (Application.window);
				}
			});
			Application.window.show_downloads_page ();
		}

		protected override void remove_button_clicked () {
			var remove_dialog = new RemoveDialog (release);
			remove_dialog.present (Application.window);
		}

		protected override void info_button_clicked () {
			var description_dialog = new DescriptionDialog (release);
			description_dialog.present (Application.window);
		}

		void release_displayed_title_changed () {
			var usage_count = 0;
			if (release.state == Models.BaseRelease.State.UP_TO_DATE)
				usage_count = release.runner.group.launcher.get_compatibility_tool_usage_count (release.title != "SteamTinkerLaunch" ? release.title : "Proton-stl");

			set_title ("%s%s".printf (release.displayed_title, usage_count > 0 ? " (%s)".printf (_("Used")) : ""));
			set_tooltip_text (usage_count > 0 ? _("%s is used by %i game(s)").printf (release.displayed_title, usage_count) : release.displayed_title);

			only_show();
		}

		void release_state_changed () {
			var installed = release.state == Models.BaseRelease.State.UP_TO_DATE;
			var busy = release.state == Models.BaseRelease.State.BUSY_INSTALLING ||
						release.state == Models.BaseRelease.State.BUSY_REMOVING ||
						release.state == Models.BaseRelease.State.BUSY_UPDATING;

			install_button.set_visible (!installed);
			remove_button.set_visible (installed);
			open_button.set_visible (installed);
			update_button.set_visible (installed);

			install_button.set_sensitive (!busy);
			open_button.set_sensitive (!busy);

			if (release.title.contains ("Latest")) {
				remove_button.set_sensitive (!busy && !Application.window.updating);
				update_button.set_sensitive (!busy && !Application.window.updating);
			} else {
				remove_button.set_sensitive (!busy);
				update_button.set_sensitive (!busy);
			}

			if (busy) {
				var tooltip_text = _("This tool is currently being installed");
				if (Models.DownloadManager.instance.is_downloading (release)) {
					tooltip_text = _("This tool is currently being downloaded");
					install_button.add_css_class ("bounce-animation");
				}

				if (release.state == Models.BaseRelease.State.BUSY_REMOVING) {
					tooltip_text = _("This tool is currently being removed");
					remove_button.add_css_class ("bounce-animation");
				}
				if (release.state == Models.BaseRelease.State.BUSY_UPDATING) {
					tooltip_text = _("This tool is currently being updated");
					update_button.add_css_class ("bounce-animation");
				}

				install_button.set_tooltip_text (tooltip_text);
				remove_button.set_tooltip_text (tooltip_text);
				update_button.set_tooltip_text (tooltip_text);
				open_button.set_tooltip_text (tooltip_text);
			} else {
				install_button.set_tooltip_text (_("Install %s").printf (release.title));
				install_button.remove_css_class ("bounce-animation");
				remove_button.set_tooltip_text (_("Delete %s").printf (release.title));
				remove_button.remove_css_class ("bounce-animation");
				update_button.set_tooltip_text (_("Update the runner if a newer version is available"));
				update_button.remove_css_class ("bounce-animation");
				open_button.set_tooltip_text (_("Open runner directory"));

				if (Application.window.updating && release.title.contains ("Latest")) {
					var updating_text = _("The application is currently updating its runners");
					remove_button.set_tooltip_text (updating_text);
					update_button.set_tooltip_text (updating_text);
				}
			}
		}
	}
}
