namespace ProtonPlus.Widgets.Tools {
    public class ReleaseRow : Adw.ActionRow {
        public signal void release_selected (Models.Release release);
        protected Models.Release release { get; set; }

        Gtk.Button update_button { get; set; }
        Gtk.Button open_button { get; set; }
        Gtk.Button remove_button { get; set; }
        Gtk.Button install_button { get; set; }
        Gtk.Button cancel_button { get; set; }
        Gtk.Button progress_button { get; set; }
        Widgets.CircularProgressBar progress_bar { get; set; }
        Gtk.Label speed_label { get; set; }
        Gtk.Label time_label { get; set; }
        Gtk.Popover info_popover { get; set; }
        Gtk.Popover details_popover { get; set; }

        public ReleaseRow (Models.Release release) {
            Object (title: release.title, subtitle: release.release_date, activatable: true);

            this.release = release;

            var icon = new Gtk.Image.from_icon_name ("box-open-symbolic");

            remove_button = new Gtk.Button.from_icon_name ("trash-symbolic");
            remove_button.set_tooltip_text (_ ("Delete %s").printf (release.title));
            remove_button.add_css_class ("flat");
            remove_button.clicked.connect (remove_button_clicked);

            install_button = new Gtk.Button.from_icon_name ("download-2-symbolic");
            install_button.set_tooltip_text (_ ("Install %s").printf (release.title));
            install_button.add_css_class ("flat");
            install_button.clicked.connect (install_button_clicked);

            cancel_button = new Gtk.Button.from_icon_name ("circle-xmark-symbolic");
            cancel_button.set_tooltip_text (_ ("Cancel installation"));
            cancel_button.add_css_class ("flat");
            cancel_button.clicked.connect (() => { release.canceled = true; });

            progress_bar = new Widgets.CircularProgressBar ();
            progress_bar.set_valign (Gtk.Align.CENTER);
            progress_bar.set_size_request (24, 24);
            progress_bar.line_width = 2;
            progress_bar.show_text = true;

            progress_button = new Gtk.Button ();
            progress_button.set_child (progress_bar);
            progress_button.add_css_class ("flat");
            progress_button.set_tooltip_text (_ ("Show installation details"));
            progress_button.clicked.connect (() => { info_popover.popup (); });

            speed_label = new Gtk.Label (_ ("Speed: 0 KB/s"));
            speed_label.set_halign (Gtk.Align.START);
            time_label = new Gtk.Label (_ ("Remaining time: --"));
            time_label.set_halign (Gtk.Align.START);

            var info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            info_box.set_margin_top (12);
            info_box.set_margin_bottom (12);
            info_box.set_margin_start (12);
            info_box.set_margin_end (12);
            info_box.append (speed_label);
            info_box.append (time_label);

            info_popover = new Gtk.Popover ();
            info_popover.set_parent (progress_button);
            info_popover.set_autohide (true);
            info_popover.set_child (info_box);

            activated.connect (() => release_selected (release));

            var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            input_box.set_margin_end (10);
            input_box.set_valign (Gtk.Align.CENTER);
            input_box.add_css_class ("linked");
            input_box.add_css_class ("tools-release-row-input-box");

            if (release.title.contains ("Latest") || release.runner is Models.Tools.SteamTinkerLaunch) {
                update_button = new Gtk.Button.from_icon_name ("arrow-rotate-symbolic");
                update_button.add_css_class ("flat");
                update_button.set_tooltip_text (_ ("Update the runner if a newer version is available"));
                update_button.clicked.connect (update_button_clicked);

                input_box.append (update_button);
            }

            if (release.install_location != null) {
                open_button = new Gtk.Button.from_icon_name ("folder-open-2-symbolic");
                open_button.set_tooltip_text (_ ("Open tool directory"));
                open_button.add_css_class ("flat");
                open_button.clicked.connect (open_button_clicked);

                input_box.append (open_button);
            }

            input_box.append (remove_button);
            input_box.append (install_button);
            input_box.append (progress_button);
            input_box.append (cancel_button);

            var tool_name = (release.runner is Models.Tools.SteamTinkerLaunch) ? "Proton-stl" : release.title;
            var count = release.runner.group.launcher.get_compatibility_tool_usage_count (tool_name);
            if (count > 0) {
                var usage_pill = new Gtk.Label (count.to_string ());
                usage_pill.add_css_class ("usage-pill");
                usage_pill.set_valign (Gtk.Align.CENTER);
                usage_pill.set_margin_end (6);
                usage_pill.set_tooltip_text (ngettext ("Used by %i game", "Used by %i games", count).printf (count));
                add_suffix (usage_pill);
            }

            add_prefix (icon);
            add_suffix (input_box);

            release.notify["state"].connect (release_state_changed);
            release.notify["progress"].connect (release_progress_changed);
            release.notify["speed-kbps"].connect (release_progress_changed);
            release.notify["seconds-remaining"].connect (release_progress_changed);

            release.notify_property ("state");
        }

        public override void dispose () {
            info_popover.unparent ();
            details_popover.unparent ();
            base.dispose ();
        }

        void release_state_changed () {
            var installed = release.state == Models.Release.State.UP_TO_DATE || release.state == Models.Release.State.UPDATE_AVAILABLE;
            var downloading = release.state == Models.Release.State.BUSY_INSTALLING ||
            release.state == Models.Release.State.BUSY_UPDATING;
            var busy = downloading || release.state == Models.Release.State.BUSY_REMOVING;

            install_button.set_visible (!installed && !downloading);
            progress_button.set_visible (downloading);
            cancel_button.set_visible (downloading);
            remove_button.set_visible (installed);
            update_button?.set_visible (installed);
            open_button?.set_visible (installed);

            install_button.set_sensitive (!busy);
            remove_button.set_sensitive (!busy);
            update_button?.set_sensitive (!busy);
            open_button?.set_sensitive (!busy);
        }

        void update_button_clicked () {
            release.update.begin ((obj, res) => {
                var code = release.update.end (res);
                if (code == ReturnCode.RUNNER_UPDATED) {
                    Utils.DownloadManager.instance.tool_updated (release, true);
                } else if (code == ReturnCode.NOTHING_TO_UPDATE) {
                    Utils.DownloadManager.instance.tool_updated (release, false);
                } else if (!release.canceled) {
                    var dialog = new Main.ErrorDialog (_ ("Couldn't update %s").printf (release.title), _ ("Please report this issue on GitHub."));
                    dialog.present ((Gtk.Window) this.get_root ());
                }
            });
        }

        void open_button_clicked () {
            Utils.System.open_uri ("file://%s".printf (release.install_location));
        }

        void release_progress_changed () {
            if (release.is_percent && release.progress != null) {
                var progress_text = release.progress.replace ("%", "");
                double fraction = double.parse (progress_text) / 100.0;
                progress_bar.fraction = fraction;
            } else {
                progress_bar.pulse ();
            }

            speed_label.set_label (_ ("Speed: %s/s").printf (Utils.Filesystem.convert_bytes_to_string ((int64) (release.speed_kbps * 1024))));

            if (release.seconds_remaining >= 0) {
                time_label.set_label (_ ("Remaining time: %s").printf (format_time (release.seconds_remaining)));
            } else {
                time_label.set_label (_ ("Remaining time: --"));
            }
        }

        string format_time (double seconds) {
            int total_seconds = (int) seconds;
            int h = total_seconds / 3600;
            int m = (total_seconds % 3600) / 60;
            int s = total_seconds % 60;

            if (h > 0) {
                return _ ("%dh %dm %ds").printf (h, m, s);
            } else if (m > 0) {
                return _ ("%dm %ds").printf (m, s);
            } else {
                return _ ("%ds").printf (s);
            }
        }

        protected virtual void install_button_clicked () {
            release.install.begin ((obj, res) => {
                if (release.install.end (res) != ReturnCode.RUNNER_INSTALLED && !release.canceled) {
                    var dialog = new Main.ErrorDialog (_ ("Couldn't install %s").printf (release.title), _ ("Please report this issue on GitHub."));
                    dialog.present ((Gtk.Window) this.get_root ());
                }
            });
        }

        protected virtual void remove_button_clicked () {
            var remove_dialog = new RemoveDialog (release);
            remove_dialog.present ((Gtk.Window) this.get_root ());
        }
    }
}