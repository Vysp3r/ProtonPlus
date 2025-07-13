namespace ProtonPlus.Widgets.ReleaseRows {
	public class LatestRow : ReleaseRow {
        Models.Releases.Latest release { get; set; }

        Gtk.Button upgrade_button { get; set; }

		public LatestRow (Models.Releases.Latest release) {
			this.release = release;

            upgrade_button = new Gtk.Button ();
			upgrade_button.add_css_class ("flat");
			upgrade_button.clicked.connect (upgrade_button_clicked);

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

        void upgrade_button_clicked () {
            
        }

        void release_displayed_title_changed () {
			set_title (release.displayed_title);
		}

        void release_state_changed () {
			var installed = release.state == Models.Release.State.UP_TO_DATE || release.state == Models.Release.State.UPDATE_AVAILABLE;
			var updated = release.state == Models.Release.State.UP_TO_DATE;

			install_button.set_visible (!installed);
			remove_button.set_visible (installed);
			upgrade_button.set_visible (installed);

			if (upgrade_button.get_visible ()) {
				upgrade_button.set_icon_name (updated ? "circle-check-symbolic" : "circle-chevron-up-symbolic");
				upgrade_button.set_tooltip_text (updated ? _("Up-to-date") : _("Update to the latest version"));
			}
		}
	}
}
