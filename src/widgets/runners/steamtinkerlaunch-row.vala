namespace ProtonPlus.Widgets {
	public class SteamTinkerLaunchRow : ReleaseRow {
		public Gtk.Button upgrade_button { get; set; }

		Models.Releases.SteamTinkerLaunch release;

		construct {
			upgrade_button = new Gtk.Button ();
			upgrade_button.add_css_class ("flat");
			upgrade_button.clicked.connect (upgrade_button_clicked);

			input_box.append (upgrade_button);
		}

		public SteamTinkerLaunchRow (Models.Releases.SteamTinkerLaunch release) {
			this.release = release;

			if (release.runner.group.launcher.installation_type != Models.Launcher.InstallationTypes.SYSTEM) {
				input_box.remove (install_button);
				input_box.remove (remove_button);
				input_box.remove (upgrade_button);
			} else {
				input_box.remove (info_button);
			}


			release.notify["displayed-title"].connect (release_displayed_title_changed);

			release_displayed_title_changed ();

			release.notify["state"].connect (release_state_changed);

			release_state_changed ();
		}

		protected override void install_button_clicked () {
			// Steam Deck doesn't need any external dependencies.
			if (!Globals.IS_STEAM_OS) {
				dependency_check.begin ((obj, res) => {
					var missing_dependencies = dependency_check.end (res);

					if (missing_dependencies != "") {
						var alert_dialog = new Adw.AlertDialog (_("Warning"), "%s\n\n%s\n%s".printf (_("You are missing the following dependencies for %s:").printf (title), missing_dependencies, _("Installation will be canceled.")));

						alert_dialog.add_response ("ok", _("OK"));

						alert_dialog.present (Widgets.Application.window);

						return;
					} else {
						external_install_check ();
					}
				});
			} else {
				external_install_check ();
			}
		}

		async string dependency_check () {
			var missing_dependencies = "";

			var yad_installed = false;
			if (yield Utils.System.check_dependency ("yad")) {
				string yad_version_output = yield Utils.System.run_command ("yad --version");

				float version = float.parse (yad_version_output.split (" ")[0]);
				yad_installed = version >= 7.2;
			}
			if (!yad_installed)missing_dependencies += "yad >= 7.2\n";

			if (!(yield Utils.System.check_dependency ("awk")) && !(yield Utils.System.check_dependency ("gawk")))missing_dependencies += "awk/gawk\n";
			if (!(yield Utils.System.check_dependency ("git")))missing_dependencies += "git\n";
			if (!(yield Utils.System.check_dependency ("pgrep")))missing_dependencies += "pgrep\n";
			if (!(yield Utils.System.check_dependency ("unzip")))missing_dependencies += "unzip\n";
			if (!(yield Utils.System.check_dependency ("wget")))missing_dependencies += "wget\n";
			if (!(yield Utils.System.check_dependency ("xdotool")))missing_dependencies += "xdotool\n";
			if (!(yield Utils.System.check_dependency ("xprop")))missing_dependencies += "xprop\n";
			if (!(yield Utils.System.check_dependency ("xrandr")))missing_dependencies += "xrandr\n";
			if (!(yield Utils.System.check_dependency ("xxd")))missing_dependencies += "xxd\n";
			if (!(yield Utils.System.check_dependency ("xwininfo")))missing_dependencies += "xwininfo\n";

			return missing_dependencies;
		}

		void external_install_check () {
			var has_external_install = release.detect_external_locations ();

			if (has_external_install) {
				var alert_dialog = new Adw.AlertDialog (_("Warning"), "%s\n\n%s".printf (_("It looks like you currently have another version of %s which was not installed by ProtonPlus.").printf (title.split (" ")[0]), _("Do you want to reinstall it with ProtonPlus?")));

				alert_dialog.add_response ("no", _("No"));
				alert_dialog.add_response ("yes", _("Yes"));

				alert_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DEFAULT);
				alert_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);

				alert_dialog.choose.begin (Widgets.Application.window, null, (obj, res) => {
					string response = alert_dialog.choose.end (res);

					if (response == "yes")
						start_install ();
				});
			} else {
				start_install ();
			}
		}

		void start_install () {
			var install_dialog = new InstallDialog (release);
			install_dialog.present (Application.window);
		}

		protected override void remove_button_clicked () {
			var parameters = new Models.Releases.SteamTinkerLaunch.STL_Remove_Parameters ();
			parameters.delete_config = false;
			parameters.user_request = true;

			var remove_config_check = new Gtk.CheckButton.with_label (_("Check this to also delete your configuration files."));
			remove_config_check.activate.connect (() => {
				parameters.delete_config = remove_config_check.get_active ();
			});

			var remove_dialog = new RemoveDialog (release, parameters);
			remove_dialog.set_extra_child (remove_config_check);
			remove_dialog.present (Application.window);
		}

		void upgrade_button_clicked () {
			if (release.state == Models.Release.State.UP_TO_DATE) {
				var dialog = new Adw.AlertDialog (_("Warning"), _("%s is already up-to-date.").printf (release.title));
				dialog.add_response ("ok", _("OK"));
				dialog.present (Application.window);
			} else {
				var upgrade_dialog = new UpgradeDialog (release);
				upgrade_dialog.present (Application.window);
			}
		}

		protected override void info_button_clicked () {
			Adw.AlertDialog? alert_dialog = null;
			switch (release.runner.group.launcher.installation_type) {
			case Models.Launcher.InstallationTypes.FLATPAK :
				var command_label = new Gtk.Label ("flatpak install com.valvesoftware.Steam.Utility.steamtinkerlaunch");
				command_label.set_selectable (true);
				alert_dialog = new Adw.AlertDialog (_("Warning"), _("To install %s for the %s, please run the following command:").printf (release.title, "Steam Flatpak"));
				alert_dialog.set_extra_child (command_label);
				break;
			case Models.Launcher.InstallationTypes.SNAP:
				alert_dialog = new Adw.AlertDialog (_("Warning"), _("There's currently no known way for us to install %s for the %s.").printf (release.title, "Steam Snap"));
				break;
			default:
				break;
			}
			if (alert_dialog != null) {
				alert_dialog.add_response ("ok", _("OK"));

				alert_dialog.present (Application.window);
			}
		}

		protected override void open_button_clicked () {
			Utils.System.open_uri ("file://%s".printf (release.base_location));
		}

		void release_displayed_title_changed () {
			set_title (release.displayed_title);

			only_show();
		}

		void release_state_changed () {
			var installed = release.state == Models.Release.State.UP_TO_DATE || release.state == Models.Release.State.UPDATE_AVAILABLE;
			var updated = release.state == Models.Release.State.UP_TO_DATE;

			install_button.set_visible (!installed);
			remove_button.set_visible (installed);
			upgrade_button.set_visible (installed);
			open_button.set_visible (installed);

			if (upgrade_button.get_visible ()) {
				upgrade_button.set_icon_name (updated ? "circle-check-symbolic" : "circle-chevron-up-symbolic");
				upgrade_button.set_tooltip_text (updated ? _("Up-to-date") : _("Update to the latest version"));
			}
		}
	}
}
