namespace ProtonPlus.Widgets {
	public class DownloadRow : Adw.ActionRow {
		public Models.Release<Models.Parameters> release { get; private set; }
		private Gtk.ProgressBar progress_bar;
		private Gtk.Button cancel_button;
		private uint pulse_id;

		public DownloadRow(Models.Release<Models.Parameters> release) {
			this.release = release;
			set_title(release.title);

			progress_bar = new Gtk.ProgressBar();
			progress_bar.set_show_text(true);
			progress_bar.set_valign(Gtk.Align.CENTER);
			progress_bar.set_size_request(200, -1);

			cancel_button = new Gtk.Button.from_icon_name("window-close-symbolic");
			cancel_button.add_css_class("flat");
			cancel_button.set_valign(Gtk.Align.CENTER);
			cancel_button.clicked.connect(() => {
				release.canceled = true;
			});

			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
			box.append(progress_bar);
			box.append(cancel_button);

			add_suffix(box);

			release.notify["progress"].connect(update_progress);
			release.notify["speed-kbps"].connect(update_stats);
			release.notify["seconds-remaining"].connect(update_stats);
			release.notify["step"].connect(update_step);

			update_progress();
			update_step();

			pulse_id = Timeout.add(25, () => {
				if (release.step != Models.Release.Step.DOWNLOADING) {
					progress_bar.pulse();
				}
				return true;
			});

			destroy.connect(() => {
				if (pulse_id > 0) {
					Source.remove(pulse_id);
					pulse_id = 0;
				}
			});
		}

		private void update_progress() {
			update_stats();
			progress_bar.set_fraction(release.progress != null ? double.parse(release.progress) / 100.0 : 0);
		}

		private void update_stats() {
			var download_speed = release.speed_kbps >= 1000 ? "%.2f MB/s".printf(release.speed_kbps / 1024.0) : "%.2f KB/s".printf(release.speed_kbps);
			var progress_text = "%s - %s".printf(_("Downloading"), download_speed);

			if (release.seconds_remaining != null) {
				int s = (int)release.seconds_remaining % 60;
				int m = ((int)release.seconds_remaining / 60) % 60;
				int h = (int)release.seconds_remaining / 3600;

				if (h > 0) progress_text += " (%02d:%02d:%02d)".printf(h, m, s);
				else if (m > 0) progress_text += " (%02d:%02d)".printf(m, s);
				else progress_text += " (%ds)".printf(s);
			}
			progress_bar.set_text(progress_text);
		}

		private void update_step() {
			switch (release.step) {
				case Models.Release.Step.DOWNLOADING:
					update_progress();
					break;
				case Models.Release.Step.EXTRACTING:
					progress_bar.set_text(_("Extracting"));
					break;
				case Models.Release.Step.MOVING:
					progress_bar.set_text(_("Moving"));
					break;
				default:
					progress_bar.set_text(null);
					break;
			}
		}
	}
}
