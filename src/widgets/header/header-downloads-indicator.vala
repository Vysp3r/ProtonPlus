namespace ProtonPlus.Widgets.Header {
    /// A compact live view of the downloads owned by DownloadManager.
    public class DownloadsIndicator : Gtk.Box {
        public signal void download_selected (Models.Release release);

        private Utils.DownloadManager manager;
        private Gee.HashMap<Models.Release, DownloadEntry> entries;
        private Gtk.MenuButton button;
        private Gtk.Image icon;
        private Gtk.Label badge;
        private Gtk.ListBox downloads_list;
        private Gtk.Popover downloads_popover;
        private ulong download_added_handler = 0;
        private ulong download_removed_handler = 0;

        public DownloadsIndicator () {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

            manager = Utils.DownloadManager.instance;
            entries = new Gee.HashMap<Models.Release, DownloadEntry> ();

            icon = new Gtk.Image.from_icon_name ("download-2-symbolic");
            badge = new Gtk.Label ("0");
            badge.add_css_class ("downloads-indicator-badge");

            var button_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            button_content.append (icon);
            button_content.append (badge);
            button = new Gtk.MenuButton ();
            button.set_child (button_content);
            button.add_css_class ("flat");
            button.set_tooltip_text (_("Active downloads"));
            append (button);

            downloads_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            downloads_list.add_css_class ("boxed-list");
            downloads_list.add_css_class ("downloads-popover-list");

            var title = new Gtk.Label (_("Downloads")) {
                halign = Gtk.Align.START,
                css_classes = { "title-4" }
            };

            var scrolled = new Gtk.ScrolledWindow () {
                child = downloads_list,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                propagate_natural_height = true,
                max_content_height = 360
            };

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                width_request = 360
            };
            content.append (title);
            content.append (scrolled);

            downloads_popover = new Gtk.Popover ();
            downloads_popover.set_child (content);
            button.set_popover (downloads_popover);

            download_added_handler = manager.download_added.connect (add_download);
            download_removed_handler = manager.download_removed.connect (remove_download);

            foreach (var release in manager.active_downloads)
                add_download (release);

            update_badge ();
        }

        public override void dispose () {
            if (download_added_handler != 0) {
                manager.disconnect (download_added_handler);
                download_added_handler = 0;
            }

            if (download_removed_handler != 0) {
                manager.disconnect (download_removed_handler);
                download_removed_handler = 0;
            }

            foreach (var entry in entries.values)
                entry.disconnect_release_signals ();
            entries.clear ();

            base.dispose ();
        }

        private void add_download (Models.Release release) {
            if (entries.has_key (release))
                return;

            var entry = new DownloadEntry (release);
            entry.activated.connect (() => {
                downloads_popover.popdown ();
                download_selected (release);
            });
            entries.set (release, entry);
            downloads_list.append (entry);
            update_badge ();
        }

        private void remove_download (Models.Release release) {
            var entry = entries.get (release);
            if (entry == null)
                return;

            downloads_list.remove (entry);
            entries.unset (release);
            entry.disconnect_release_signals ();
            update_badge ();
        }

        private void update_badge () {
            var count = entries.size;
            badge.set_label (count.to_string ());
            set_visible (count > 0);
            if (count > 0)
                icon.add_css_class ("downloads-indicator-active");
            else
                icon.remove_css_class ("downloads-indicator-active");
            button.set_tooltip_text (ngettext ("%u active download", "%u active downloads", count).printf (count));

            if (count == 0)
                downloads_popover.popdown ();
        }
    }

    private class DownloadEntry : Adw.ActionRow {
        private Models.Release release;
        private Gtk.ProgressBar progress_bar;
        private Gtk.Label status_label;
        private Gtk.Label metrics_label;
        private Gtk.Button cancel_button;
        private ulong progress_handler = 0;
        private ulong step_handler = 0;
        private ulong canceled_handler = 0;

        public DownloadEntry (Models.Release release) {
            Object (title: release.runner.title, activatable: true);

            this.release = release;
            set_subtitle (release.displayed_title);

            progress_bar = new Gtk.ProgressBar () {
                show_text = false,
                width_request = 132,
                valign = Gtk.Align.CENTER
            };

            status_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                xalign = 0,
                css_classes = { "caption" },
                ellipsize = Pango.EllipsizeMode.END,
                max_width_chars = 24
            };

            metrics_label = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                xalign = 0,
                css_classes = { "caption" },
                ellipsize = Pango.EllipsizeMode.END,
                max_width_chars = 24
            };

            var progress_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                valign = Gtk.Align.CENTER,
                width_request = 150,
                margin_top = 6
            };
            progress_box.append (progress_bar);
            progress_box.append (status_label);
            progress_box.append (metrics_label);

            cancel_button = new Gtk.Button.from_icon_name ("circle-xmark-symbolic") {
                valign = Gtk.Align.CENTER
            };
            cancel_button.add_css_class ("flat");
            cancel_button.set_tooltip_text (_("Cancel"));
            cancel_button.clicked.connect (() => {
                release.canceled = true;
                update_display ();
            });

            add_suffix (progress_box);
            add_suffix (cancel_button);

            progress_handler = release.progress_updated.connect (update_display);
            step_handler = release.notify["step"].connect (update_display);
            canceled_handler = release.notify["canceled"].connect (update_display);
            update_display ();
        }

        public override void dispose () {
            disconnect_release_signals ();
            base.dispose ();
        }

        public void disconnect_release_signals () {
            if (progress_handler != 0) {
                release.disconnect (progress_handler);
                progress_handler = 0;
            }

            if (step_handler != 0) {
                release.disconnect (step_handler);
                step_handler = 0;
            }

            if (canceled_handler != 0) {
                release.disconnect (canceled_handler);
                canceled_handler = 0;
            }
        }

        private void update_display () {
            var step_text = get_step_text ();
            var percent_text = "";

            if (release.is_percent && release.progress != null) {
                var value = release.progress.replace ("%", "");
                progress_bar.fraction = double.parse (value) / 100.0;
                percent_text = release.progress;
            } else {
                progress_bar.fraction = 0.0;
            }

            if (release.canceled) {
                step_text = _("Cancelling");
                cancel_button.set_sensitive (false);
                cancel_button.set_tooltip_text (_("Cancelling"));
            }

            var status = step_text;
            if (percent_text != "")
                status += " · %s".printf (percent_text);

            var speed = "--";
            if (release.step == Models.Release.Step.DOWNLOADING) {
                speed = "%s/s".printf (Utils.Filesystem.convert_bytes_to_string (
                    (int64) (release.speed_kbps * 1024)
                ));
            }

            status_label.set_label (status);
            metrics_label.set_label ("%s · %s".printf (
                speed,
                format_eta (release.step == Models.Release.Step.DOWNLOADING ? release.seconds_remaining : -1)
            ));
        }

        private string get_step_text () {
            switch (release.step) {
                case Models.Release.Step.DOWNLOADING:
                    return _("Downloading");
                case Models.Release.Step.EXTRACTING:
                    return _("Extracting");
                case Models.Release.Step.MOVING:
                    return _("Installing");
                case Models.Release.Step.REMOVING:
                    return _("Removing");
                default:
                    return _("Preparing");
            }
        }

        private string format_eta (double seconds) {
            if (seconds < 0)
                return _("ETA: --");

            var total_seconds = (int) seconds;
            var hours = total_seconds / 3600;
            var minutes = (total_seconds % 3600) / 60;
            var remaining_seconds = total_seconds % 60;

            if (hours > 0)
                return _("ETA: %dh %dm").printf (hours, minutes);
            if (minutes > 0)
                return _("ETA: %dm %ds").printf (minutes, remaining_seconds);
            return _("ETA: %ds").printf (remaining_seconds);
        }
    }
}
