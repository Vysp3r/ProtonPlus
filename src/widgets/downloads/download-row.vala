namespace ProtonPlus.Widgets {
	public class DownloadRow : Adw.ActionRow {
		public Models.BaseRelease release { get; private set; }
		private Gtk.ProgressBar progress_bar;
		private Gtk.Button cancel_button;
		private Gtk.Box box;
		private uint pulse_id;

		public DownloadRow(Models.BaseRelease release) {
			this.release = release;
			set_title(release.displayed_title != null ? release.displayed_title : release.title);
			add_prefix(new Gtk.Image.from_resource(release.runner.group.launcher.icon_path));

			progress_bar = new Gtk.ProgressBar();
			progress_bar.set_show_text(false);
			progress_bar.set_valign(Gtk.Align.CENTER);
			progress_bar.set_size_request(180, -1);

			cancel_button = new Gtk.Button.from_icon_name("process-stop-symbolic");
			cancel_button.add_css_class("flat");
			cancel_button.add_css_class("circular");
			cancel_button.set_valign(Gtk.Align.CENTER);
			cancel_button.visible = release.state != Models.BaseRelease.State.BUSY_UPDATING;
			cancel_button.clicked.connect(() => {
				release.canceled = true;
			});

			box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
			box.append(progress_bar);
			box.append(cancel_button);

			add_suffix(box);

			if (release.is_finished) {
				set_finished(release.install_success);
			} else {
				release.notify["progress"].connect(update_progress);
				release.notify["speed-kbps"].connect(update_stats);
				release.notify["seconds-remaining"].connect(update_stats);
				release.notify["step"].connect(update_step);

				update_progress();
				update_step();

				pulse_id = Timeout.add(25, () => {
					if (release.step != Models.BaseRelease.Step.DOWNLOADING || !release.is_percent) {
						progress_bar.pulse();
					}
					return true;
				});
			}

			destroy.connect(() => {
				if (pulse_id > 0) {
					Source.remove(pulse_id);
					pulse_id = 0;
				}
				
				try {
					release.notify["progress"].disconnect(update_progress);
					release.notify["speed-kbps"].disconnect(update_stats);
					release.notify["seconds-remaining"].disconnect(update_stats);
					release.notify["step"].disconnect(update_step);
				} catch (Error e) {}
			});
		}

		private void update_progress() {
			update_stats();
			if (release.progress != null && release.is_percent) {
				var progress = release.progress;
				if (progress.has_suffix("%"))
					progress = progress.substring(0, progress.length - 1);
				progress_bar.set_fraction(double.parse(progress) / 100.0);
			} else {
				progress_bar.set_fraction(0);
			}
		}

		private void update_stats() {
			cancel_button.visible = release.state != Models.BaseRelease.State.BUSY_UPDATING;
			var download_speed = release.speed_kbps >= 1000 ? "%.2f MB/s".printf(release.speed_kbps / 1024.0) : "%.2f KB/s".printf(release.speed_kbps);
			var state_text = release.state == Models.BaseRelease.State.BUSY_UPDATING ? _("Updating") : _("Downloading");
			var progress_text = "%s - %s".printf(state_text, download_speed);

			if (release.seconds_remaining != null) {
				int s = (int)release.seconds_remaining % 60;
				int m = ((int)release.seconds_remaining / 60) % 60;
				int h = (int)release.seconds_remaining / 3600;

				if (h > 0) progress_text += " (%02d:%02d:%02d)".printf(h, m, s);
				else if (m > 0) progress_text += " (%02d:%02d)".printf(m, s);
				else progress_text += " (%ds)".printf(s);
			}
			set_subtitle(progress_text);
		}

		private void update_step() {
			switch (release.step) {
				case Models.BaseRelease.Step.DOWNLOADING:
					update_progress();
					break;
				case Models.BaseRelease.Step.EXTRACTING:
					set_subtitle(_("Extracting"));
					break;
				case Models.BaseRelease.Step.MOVING:
					set_subtitle(_("Moving"));
					break;
				default:
					set_subtitle("");
					break;
			}
		}

		public void set_finished(bool success) {
			if (pulse_id > 0) {
				Source.remove(pulse_id);
				pulse_id = 0;
			}
			progress_bar.set_visible(false);
			cancel_button.set_visible(false);

			// Remove existing icons if any (to avoid duplicates)
			var child = box.get_first_child();
			while (child != null) {
				var next = child.get_next_sibling();
				if (child is Gtk.Image) {
					box.remove(child);
				}
				child = next;
			}

			Gtk.Image icon;

			if (release.canceled) {
				set_subtitle(_("Canceled"));
				icon = new Gtk.Image.from_icon_name("window-close-symbolic");
			} else if (success) {
				set_subtitle(_("Success"));
				icon = new Gtk.Image.from_icon_name("emblem-ok-symbolic");
			} else {
				set_subtitle(_("Error"));
				icon = new Gtk.Image.from_icon_name("dialog-error-symbolic");
			}

			box.append(icon);
		}
	}
}
