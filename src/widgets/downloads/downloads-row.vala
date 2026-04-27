namespace ProtonPlus.Widgets.Downloads {
    public class Row : Adw.ActionRow {
        public Models.Release release { get; private set; }
        private Gtk.ProgressBar progress_bar;
        private Gtk.Button cancel_button;
        private Gtk.Box box;
        private uint pulse_id;

        public Row (Models.Release release) {
            this.release = release;
            set_title (release.displayed_title != null ? release.displayed_title : release.title);
            add_prefix (new Gtk.Image.from_resource(release.runner.group.launcher.icon_path));

            progress_bar = new Gtk.ProgressBar();
            progress_bar.set_show_text (false);
            progress_bar.set_valign (Gtk.Align.CENTER);
            progress_bar.set_size_request (180, -1);

            cancel_button = new Gtk.Button.from_icon_name("circle-xmark-symbolic");
            cancel_button.add_css_class ("flat");
            cancel_button.add_css_class ("circular");
            cancel_button.tooltip_text = _ ("Cancel");
            cancel_button.set_valign (Gtk.Align.CENTER);
            cancel_button.visible = release.state != Models.Release.State.BUSY_UPDATING;
            cancel_button.clicked.connect (() => {
                release.canceled = true;
            });

            box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            box.append (progress_bar);
            box.append (cancel_button);

            add_suffix (box);

            if (release.is_finished) {
                set_finished (release.install_success);
            } else {
                release.notify["progress"].connect (update_progress);
                release.notify["speed-kbps"].connect (update_stats);
                release.notify["seconds-remaining"].connect (update_stats);
                release.notify["step"].connect (update_step);

                update_progress ();
                update_step ();

                pulse_id = Timeout.add (25, () => {
                    if (release.step != Models.Release.Step.DOWNLOADING || !release.is_percent) {
                        progress_bar.pulse ();
                    }
                    return true;
                });
            }

            destroy.connect (() => {
                if (pulse_id > 0) {
                    Source.remove (pulse_id);
                    pulse_id = 0;
                }

                release.notify["progress"].disconnect (update_progress);
                release.notify["speed-kbps"].disconnect (update_stats);
                release.notify["seconds-remaining"].disconnect (update_stats);
                release.notify["step"].disconnect (update_step);
            });
        }

        private void update_progress () {
            update_stats ();
            if (release.progress != null && release.is_percent) {
                var progress = release.progress;
                if (progress.has_suffix ("%"))
                progress = progress.substring (0, progress.length - 1);
                progress_bar.set_fraction (double.parse (progress) / 100.0);
            } else {
                progress_bar.set_fraction (0);
            }
        }

        private void update_stats () {
            cancel_button.visible = release.state != Models.Release.State.BUSY_UPDATING;
            var download_speed = release.speed_kbps >= 1000 ? "%.2f MB/s".printf (release.speed_kbps / 1024.0) : "%.2f KB/s".printf (release.speed_kbps);
            var state_text = release.state == Models.Release.State.BUSY_UPDATING ? _ ("Updating") : _ ("Downloading");
            var progress_text = "%s - %s".printf (state_text, download_speed);

            if (release.seconds_remaining != -1.0) {
                int s = (int)release.seconds_remaining % 60;
                int m = ((int)release.seconds_remaining / 60) % 60;
                int h = (int)release.seconds_remaining / 3600;

                if (h > 0) progress_text += " (%02d:%02d:%02d)".printf (h, m, s);
                    else if (m > 0) progress_text += " (%02d:%02d)".printf (m, s);
                else progress_text += " (%ds)".printf (s);
            }
            set_subtitle (progress_text);
        }

        private void update_step () {
            switch (release.step) {
                case Models.Release.Step.DOWNLOADING:
                    update_progress ();
                    break;
                case Models.Release.Step.EXTRACTING:
                    set_subtitle (_ ("Extracting"));
                    break;
                case Models.Release.Step.MOVING:
                    set_subtitle (_ ("Moving"));
                    break;
                default:
                    set_subtitle ("");
                    break;
            }
        }

        public void set_finished (bool success) {
            if (pulse_id > 0) {
                Source.remove (pulse_id);
                pulse_id = 0;
            }
            progress_bar.set_visible (false);
            cancel_button.set_visible (false);

            // Remove existing icons/buttons if any (to avoid duplicates)
            var child = box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                if (child != progress_bar && child != cancel_button) {
                    box.remove (child);
                }
                child = next;
            }

            if (release.canceled) {
                set_subtitle (_ ("Canceled"));
            } else if (success) {
                set_subtitle (_ ("Success"));
            } else {
                set_subtitle (_ ("Error"));

                var copy_button = new Gtk.Button.from_icon_name ("copy-symbolic");
                copy_button.set_valign (Gtk.Align.CENTER);
                copy_button.add_css_class ("flat");
                copy_button.add_css_class ("circular");
                copy_button.tooltip_text = _ ("Copy Error Message");
                copy_button.clicked.connect (() => {
                    var clipboard = copy_button.get_clipboard ();
                    clipboard.set_text (release.error_message ?? _ ("Unknown error"));
                });
                box.append (copy_button);

                var report_button = new Gtk.Button.from_icon_name ("github-symbolic");
                report_button.set_valign (Gtk.Align.CENTER);
                report_button.add_css_class ("flat");
                report_button.add_css_class ("circular");
                report_button.tooltip_text = _ ("Report Issue");
                report_button.clicked.connect (() => {
                    Utils.System.open_uri ("https://github.com/Vysp3r/ProtonPlus/issues/new?template=bug_report.md");
                });
                box.append (report_button);
            }
        }
    }
}
