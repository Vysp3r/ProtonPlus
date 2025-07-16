namespace ProtonPlus.Widgets {
	public class UpgradeDialog : Adw.AlertDialog {
		Gtk.ProgressBar progress_bar { get; set; }
		bool stop { get; set; }
		bool canceled { get; set; }
		Models.Releases.Upgrade<Models.Parameters> release { get; set; }
		public signal void done (bool result);

		public UpgradeDialog (Models.Releases.Upgrade<Models.Parameters> release) {
			this.release = release;

			progress_bar = new Gtk.ProgressBar ();
			progress_bar.set_show_text (true);

			response.connect (response_changed);

			set_heading (_("Upgrade %s").printf (release.title));
			set_extra_child (progress_bar);

			if (release.title.contains ("SteamTinkerLaunch")) {
				set_can_close (false);
			} else {
				add_response ("cancel", _("Cancel"));
				set_response_appearance ("cancel", Adw.ResponseAppearance.DESTRUCTIVE);
				set_close_response ("cancel");

				release.notify["progress"].connect (release_progress_changed);
			}

			Timeout.add_full (Priority.DEFAULT, 25, () => {
				if (stop)
					return false;

				if (release.step != Models.Release.Step.DOWNLOADING)
					progress_bar.pulse ();

				return true;
			});

			release.notify["progress"].connect (release_progress_changed);

			release.notify["step"].connect (release_step_changed);

			release.upgrade.begin ((obj, res) => {
				var success = release.upgrade.end (res);

				stop = true;

				set_can_close (true);

				close ();

				done (success);

				if (!success && !canceled) {
					var dialog = new Adw.AlertDialog (_("Error"), "%s\n%s".printf (_("When trying to upgrade %s an error occurred.").printf (release.title), _("Please report this issue on GitHub.")));
					dialog.add_response ("ok", _("OK"));
					dialog.present (Application.window);
				}
			});
		}

		void response_changed (string response) {
			if (response == "cancel") {
				stop = true;
				canceled = true;
				release.canceled = true;
			}
		}

		void release_progress_changed () {
			progress_bar.set_fraction (double.parse (release.progress) / 100);
		}

		void release_step_changed () {
			switch (release.step) {
			case Models.Release.Step.DOWNLOADING:
				progress_bar.set_text (_("Downloading"));
				break;
			case Models.Release.Step.EXTRACTING:
				progress_bar.set_text (_("Extracting"));
				break;
			default:
				progress_bar.set_text (null);
				break;
			}
		}
	}
}
