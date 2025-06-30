namespace ProtonPlus.Widgets.ReleaseRows {
	public class BasicRow : ReleaseRow {
		Models.Releases.Basic release { get; set; }

		public BasicRow (Models.Releases.Basic release) {
			this.release = release;

			if (release.description == null || release.page_url == null)
				input_box.remove (info_button);

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
			set_title (release.displayed_title);
		}

		void release_state_changed () {
			var installed = release.state == Models.Release.State.UP_TO_DATE;

			install_button.set_visible (!installed);
			remove_button.set_visible (installed);
		}
	}
}
