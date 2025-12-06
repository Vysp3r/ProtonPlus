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
				remove_button.set_sensitive (!Application.window.updating);
				update_button.set_sensitive (!Application.window.updating);

				Application.window.notify["updating"].connect(() => {
					remove_button.set_sensitive (!Application.window.updating);
					update_button.set_sensitive (!Application.window.updating);
				});

				set_subtitle (_("This version will get automatically updated when there's an update available each time your launch the application if automatic updates is enabled"));
			} else {
				input_box.remove (update_button);
			}

			release.notify["displayed-title"].connect (release_displayed_title_changed);

			release_displayed_title_changed ();

			release.notify["state"].connect (release_state_changed);

			release_state_changed ();
		}

		protected override void update_button_clicked () {
			Application.window.check_for_updates.begin (release.runner as Models.Runners.Basic);
		}

		protected override void open_button_clicked () {
			Utils.System.open_uri ("file://%s".printf (release.install_location));
		}

		protected override void install_button_clicked () {
			var install_dialog = new InstallDialog (release);
			install_dialog.present (Application.window);
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
			if (release.state == Models.Release.State.UP_TO_DATE)
				usage_count = release.runner.group.launcher.get_compatibility_tool_usage_count (release.title != "SteamTinkerLaunch" ? release.title : "Proton-stl");

			set_title ("%s%s".printf (release.displayed_title, usage_count > 0 ? " (%s)".printf (_("Used")) : ""));
			set_tooltip_text (usage_count > 0 ? _("%s is used by %i game(s)").printf (release.displayed_title, usage_count) : release.displayed_title);

			only_show();
		}

		void release_state_changed () {
			var installed = release.state == Models.Release.State.UP_TO_DATE;

			install_button.set_visible (!installed);
			remove_button.set_visible (installed);
			open_button.set_visible (installed);
			update_button.set_visible (installed);
		}
	}
}
