namespace ProtonPlus.Widgets {
	public class InstallDialog : Adw.AlertDialog {
		Gtk.ProgressBar progress_bar { get; set; }
		bool stop { get; set; }
		bool canceled { get; set; }
		Models.Release<Models.Parameters> release { get; set; }
		public signal void done (bool result);

		public InstallDialog (Models.Release<Models.Parameters> release) {
			this.release = release;

			progress_bar = new Gtk.ProgressBar ();
			progress_bar.set_show_text (true);

			response.connect (response_changed);

			set_heading (_("Install %s").printf (release.title));
			set_extra_child (progress_bar);

			if (release.title.contains ("Steam Tinker Launch")) {
				set_can_close (false);
			} else {
				add_response ("cancel", _("Cancel"));
				set_response_appearance ("cancel", Adw.ResponseAppearance.DESTRUCTIVE);
				set_close_response ("cancel");
			}

			release.notify["progress"].connect (release_progress_changed);
			release.notify["speed"].connect (update_download_stat);
			release.notify["time"].connect (update_download_stat);

			Timeout.add_full (Priority.DEFAULT, 25, () => {
				if (stop)
					return false;

				if (release.step != Models.Release.Step.DOWNLOADING)
					progress_bar.pulse ();

				return true;
			});

			release.notify["step"].connect (release_step_changed);

			release.install.begin ((obj, res) => {
				var success = release.install.end (res);

				stop = true;

                done (success);

                if (!success && !canceled) {
					var dialog = new ErrorDialog (_("Couldn't install %s").printf (release.title), _("Please report this issue on GitHub."));
					dialog.present (Application.window);
				}

				set_can_close (true);

				close ();
			});
		}

		void response_changed (string response) {
			if (response == "cancel") {
				stop = true;
				canceled = true;
				release.canceled = true;
			}
		}

		void update_download_stat () {
			var download_speed = release.speed_kbps >= 1000 ? "%.2f MB/s".printf(release.speed_kbps / 1024.0) : "%.2f KB/s".printf(release.speed_kbps);

            var progress_text = "%s - %s".printf (_("Downloading"), download_speed);

            if (release.seconds_remaining != null) {
			    int s = (int) release.seconds_remaining % 60;
			    int m = ((int) release.seconds_remaining / 60) % 60;
			    int h = (int) release.seconds_remaining / 3600;

			    if (h > 0)
				    progress_text += " (%02d:%02d:%02d)".printf(h, m, s);
			    else if (m > 0)
				    progress_text += " (%02d:%02d)".printf(m, s);
			    else
				    progress_text += " (%ds)".printf(s);
            }

			progress_bar.set_text (progress_text);
		}

		void release_progress_changed () {
			update_download_stat ();

			progress_bar.set_fraction (release.progress != null ? double.parse (release.progress) / 100 : 0);
		}

		void release_step_changed () {
			switch (release.step) {
			case Models.Release.Step.DOWNLOADING:
				release_progress_changed ();
				break;
			case Models.Release.Step.EXTRACTING:
				progress_bar.set_text (_("Extracting"));
				break;
			case Models.Release.Step.MOVING:
				progress_bar.set_text (_("Moving"));
				break;
			default:
				progress_bar.set_text (null);
				break;
			}
		}
	}
}
