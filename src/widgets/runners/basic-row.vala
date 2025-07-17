namespace ProtonPlus.Widgets {
	public class BasicRow : ReleaseRow {
		Models.Releases.Basic release { get; set; }

		public BasicRow (Models.Releases.Basic release) {
			this.release = release;

			if (release.description == null || release.page_url == null)
				input_box.remove (info_button);

			if (release.title.contains ("Latest")) {
				remove_button.set_sensitive (!Application.window.updating);

				Application.window.notify["updating"].connect(() => {
					remove_button.set_sensitive (!Application.window.updating);
				});
			}

			release.notify["displayed-title"].connect (release_displayed_title_changed);

			release_displayed_title_changed ();

			release.notify["state"].connect (release_state_changed);

			release_state_changed ();
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
		}
	}
}
