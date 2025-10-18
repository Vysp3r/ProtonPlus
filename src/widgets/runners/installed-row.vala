namespace ProtonPlus.Widgets {
	public class InstalledRow : ReleaseRow {
		Models.Releases.Basic release { get; set; }
		public signal void remove_from_parent (InstalledRow row);

		public InstalledRow (Models.Releases.Basic release) {
			this.release = release;

			var usage_count = release.runner.group.launcher.get_compatibility_tool_usage_count (release.title != "SteamTinkerLaunch" ? release.title : "Proton-stl");

			set_title ("%s%s".printf (release.title, usage_count > 0 ? " (%s)".printf (_("Used")) : ""));
			set_tooltip_text (usage_count > 0 ? _("%s is used by %i game(s)").printf (release.title, usage_count) : release.title);

			install_button.set_visible (false);
			info_button.set_visible (false);

			only_show();
		}

		protected override void open_button_clicked () {
			Utils.System.open_uri ("file://%s".printf (release.install_location));
		}

		protected override void install_button_clicked () {}

		protected override void remove_button_clicked () {
			var remove_dialog = new RemoveDialog (release);
			remove_dialog.done.connect ((result) => {
				if (result)
					remove_from_parent (this);
			});

			if (release.title.contains ("SteamTinkerLaunch")) {
				var parameters = new Models.Releases.SteamTinkerLaunch.STL_Remove_Parameters ();
				parameters.delete_config = false;
				parameters.user_request = true;

				var remove_config_check = new Gtk.CheckButton.with_label (_("Check this to also delete your configuration files."));
				remove_config_check.activate.connect (() => {
					parameters.delete_config = remove_config_check.get_active ();
				});

				remove_dialog.set_extra_child (remove_config_check);
			}

			remove_dialog.present (Application.window);
		}

		protected override void info_button_clicked () {}
	}
}
