namespace ProtonPlus.Widgets.Header {
    /// A compact view of active downloads and recent failures.
    public class DownloadsIndicator : Gtk.Box {
        public signal void download_selected (Services.InstallJob job);

        private Utils.DownloadManager manager;
        private Gee.HashMap<Services.InstallJob, DownloadEntry> entries;
        private Gee.HashMap<Services.DownloadFailure, DownloadFailureEntry> failures;
        private Gtk.MenuButton button;
        private Gtk.Image icon;
        private Gtk.Label badge;
        private Gtk.Label limit_label;
        private Gtk.ListBox downloads_list;
        private Gtk.ListBox failures_list;
        private Gtk.Box failures_section;
        private Gtk.Popover downloads_popover;
        private ulong download_added_handler = 0;
        private ulong download_removed_handler = 0;
        private ulong download_failed_handler = 0;
        private ulong failure_removed_handler = 0;
        private ulong speed_limit_changed_handler = 0;
        private bool global_header_visible = true;

        public DownloadsIndicator () {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

            manager = Utils.DownloadManager.instance;
            entries = new Gee.HashMap<Services.InstallJob, DownloadEntry> ();
            failures = new Gee.HashMap<Services.DownloadFailure, DownloadFailureEntry> ();

            icon = new Gtk.Image.from_icon_name ("folder-download-symbolic");
            badge = new Gtk.Label ("0");
            badge.add_css_class ("downloads-indicator-badge");

            var button_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            button_content.append (icon);
            button_content.append (badge);
            button = new Gtk.MenuButton ();
            button.set_child (button_content);
            button.add_css_class ("flat");
            append (button);

            downloads_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            downloads_list.add_css_class ("boxed-list");
            downloads_list.add_css_class ("downloads-popover-list");
            downloads_list.row_activated.connect ((row) => {
                var entry = row as DownloadEntry;
                if (entry == null)
                    return;
                downloads_popover.popdown ();
                download_selected (entry.job);
            });

            var title = new Gtk.Label (_("Downloads")) {
                halign = Gtk.Align.START,
                css_classes = { "title-4" }
            };

            limit_label = new Gtk.Label ("") {
                halign = Gtk.Align.END,
                xalign = 1,
                hexpand = true,
                css_classes = { "caption", "dim-label" }
            };

            var title_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            title_row.append (title);
            title_row.append (limit_label);

            failures_list = new Gtk.ListBox () { selection_mode = Gtk.SelectionMode.NONE };
            failures_list.add_css_class ("boxed-list");
            var failures_title = new Gtk.Label (_("Recent Failures")) {
                halign = Gtk.Align.START,
                css_classes = { "heading" }
            };
            failures_section = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            failures_section.append (failures_title);
            failures_section.append (failures_list);

            var lists = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            lists.append (downloads_list);
            lists.append (failures_section);
            var scrolled = new Gtk.ScrolledWindow () {
                child = lists,
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
            content.append (title_row);
            content.append (scrolled);

            downloads_popover = new Gtk.Popover ();
            downloads_popover.set_child (content);
            button.set_popover (downloads_popover);
            Window.register_popover_for_controller (downloads_popover, button);

            download_added_handler = manager.download_added.connect (add_download);
            download_removed_handler = manager.download_removed.connect (remove_download);
            download_failed_handler = manager.download_failed.connect (add_failure);
            failure_removed_handler = manager.download_failure_removed.connect (remove_failure);
            speed_limit_changed_handler = manager.speed_limit_changed.connect ((new_limit) => {
                update_limit_label (new_limit);
            });

            update_limit_label (manager.speed_limit_bps);

            foreach (var job in manager.active_downloads)
                add_download (job);
            for (var i = manager.recent_failures.size - 1; i >= 0; i--)
                add_failure (manager.recent_failures[i]);

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
            if (download_failed_handler != 0) {
                manager.disconnect (download_failed_handler);
                download_failed_handler = 0;
            }
            if (failure_removed_handler != 0) {
                manager.disconnect (failure_removed_handler);
                failure_removed_handler = 0;
            }

            if (speed_limit_changed_handler != 0) {
                manager.disconnect (speed_limit_changed_handler);
                speed_limit_changed_handler = 0;
            }

            foreach (var entry in entries.values)
                entry.disconnect_release_signals ();
            entries.clear ();
            failures.clear ();

            base.dispose ();
        }

        private void add_download (Services.InstallJob job) {
            if (entries.has_key (job))
                return;

            var entry = new DownloadEntry (job);
            entries.set (job, entry);
            downloads_list.append (entry);
            update_badge ();
        }

        private void remove_download (Services.InstallJob job) {
            var entry = entries.get (job);
            if (entry == null)
                return;

            if (contains_focus (entry)) {
                foreach (var failure in failures.keys) {
                    if (failure.job == job) {
                        failures[failure].focus_action ();
                        break;
                    }
                }
            }
            downloads_list.remove (entry);
            entries.unset (job);
            entry.disconnect_release_signals ();
            update_badge ();
        }

        private void add_failure (Services.DownloadFailure failure) {
            var entry = new DownloadFailureEntry (failure);
            failures.set (failure, entry);
            failures_list.prepend (entry);
            update_badge ();
        }

        private void remove_failure (Services.DownloadFailure failure) {
            var entry = failures.get (failure);
            if (entry == null)
                return;
            var had_focus = contains_focus (entry);
            failures_list.remove (entry);
            failures.unset (failure);
            update_badge ();
            if (!had_focus)
                return;
            var active = manager.get_active_download (failure.job);
            if (active != null && entries.has_key (active))
                entries[active].grab_focus ();
            else if (failures.size > 0)
                ((DownloadFailureEntry) failures_list.get_first_child ()).focus_action ();
            else
                downloads_list.get_first_child ()?.grab_focus ();
        }

        private bool contains_focus (Gtk.Widget row) {
            var focus = get_root ()?.get_focus ();
            return focus != null && (focus == row || focus.is_ancestor (row));
        }

        private void update_badge () {
            var active_count = entries.size;
            var failed_count = failures.size;
            var count = active_count + failed_count;
            badge.set_label (count.to_string ());
            downloads_list.visible = active_count > 0;
            failures_section.visible = failed_count > 0;
            set_visible (global_header_visible && count > 0);
            var active = ngettext ("%u active download", "%u active downloads", active_count).printf (active_count);
            var failed = ngettext ("%u failed operation", "%u failed operations", failed_count).printf (failed_count);
            string description;
            if (failed_count == 0)
                description = active;
            else if (active_count == 0)
                description = failed;
            else
                description = _("%s, %s").printf (active, failed);
            icon.set_from_icon_name (active_count == 0 && failed_count > 0
                ? "dialog-warning-symbolic" : "folder-download-symbolic");
            button.set_tooltip_text (description);
            button.update_property (Gtk.AccessibleProperty.LABEL, description, -1);

            if (count == 0)
                downloads_popover.popdown ();
        }

        public void set_global_header_visible (bool visible) {
            global_header_visible = visible;
            update_badge ();
        }

        private void update_limit_label (int64 speed_limit_bps) {
            if (speed_limit_bps > 0)
                limit_label.set_label (_("Limit: %s/s").printf (format_size (speed_limit_bps)));
            else
                limit_label.set_label ("");
        }
    }

    private class DownloadFailureEntry : Adw.PreferencesRow {
        private Services.DownloadFailure failure;
        private Gtk.Button copy_button;
        private Gtk.Button retry_button;
        private Gtk.Label error_label;
        private ulong retrying_handler;

        public DownloadFailureEntry (Services.DownloadFailure failure) {
            Object (title: failure.tool_title, use_markup: false, activatable: false);
            this.failure = failure;

            var title = new Gtk.Label (failure.tool_title) {
                xalign = 0, wrap = true, wrap_mode = Pango.WrapMode.WORD_CHAR,
                lines = 2, ellipsize = Pango.EllipsizeMode.END, max_width_chars = 28,
                css_classes = { "heading" }, tooltip_text = failure.tool_title
            };
            var version = new Gtk.Label (failure.release_title) {
                xalign = 0, ellipsize = Pango.EllipsizeMode.END, max_width_chars = 28,
                css_classes = { "caption", "dim-label" }, tooltip_text = failure.release_title
            };
            var stage = failure.stage_label ();
            var status = new Gtk.Label (stage == "" ? failure.operation_label ()
                : _("%s · %s").printf (failure.operation_label (), stage)) {
                xalign = 0, wrap = true, wrap_mode = Pango.WrapMode.WORD_CHAR, max_width_chars = 28,
                css_classes = { "caption", "error" }
            };
            error_label = new Gtk.Label (failure.message) {
                xalign = 0, wrap = true, wrap_mode = Pango.WrapMode.WORD_CHAR, lines = 2,
                ellipsize = Pango.EllipsizeMode.END, max_width_chars = 28, tooltip_text = failure.message
            };
            copy_button = new Gtk.Button.with_label (_("Copy Details"));
            copy_button.clicked.connect (copy_details);
            retry_button = new Gtk.Button.with_label (_("Retry")) {
                visible = failure.retry_supported,
                sensitive = !failure.retrying
            };
            retry_button.clicked.connect (request_retry);
            retrying_handler = failure.notify["retrying"].connect (update_retry_button);

            var actions = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) { halign = Gtk.Align.END };
            actions.append (copy_button);
            actions.append (retry_button);
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                margin_top = 12, margin_bottom = 12, margin_start = 12, margin_end = 12
            };
            content.append (title);
            content.append (version);
            content.append (status);
            content.append (error_label);
            content.append (actions);
            set_child (content);
        }

        public override void dispose () {
            if (retrying_handler != 0) {
                failure.disconnect (retrying_handler);
                retrying_handler = 0;
            }
            base.dispose ();
        }

        public void focus_action () {
            if (retry_button.visible && retry_button.sensitive)
                retry_button.grab_focus ();
            else
                copy_button.grab_focus ();
        }

        private void copy_details () {
            get_clipboard ().set_text (failure.copy_details ());
            copy_button.label = _("Copied");
        }

        private void update_retry_button () {
            if (failure.retrying && retry_button.has_focus)
                copy_button.grab_focus ();
            retry_button.sensitive = !failure.retrying;
            retry_button.label = failure.retrying ? _("Retrying…") : _("Retry");
        }

        private void request_retry () {
            var entry_ref = WeakRef (this);
            var failed_operation = failure;
            Services.InstallationService.instance.retry_download.begin (failed_operation, (obj, result) => {
                if (Services.InstallationService.instance.retry_download.end (result))
                    return;
                var entry = entry_ref.get () as DownloadFailureEntry;
                if (entry != null) {
                    var feedback = _("The original operation is unavailable. Check the tool and try again.");
                    entry.error_label.label = "%s\n%s".printf (failed_operation.message, feedback);
                    entry.error_label.tooltip_text = entry.error_label.label;
                }
            });
        }
    }

    private class DownloadEntry : Adw.PreferencesRow {
        public Services.InstallJob job { get; private set; }
        private Gtk.ProgressBar progress_bar;
        private Gtk.Label status_label;
        private Gtk.Label metrics_label;
        private Gtk.Button cancel_button;
        private ulong progress_handler = 0;
        private ulong step_handler = 0;
        private ulong canceled_handler = 0;

        public DownloadEntry (Services.InstallJob job) {
            Object (title: job.tool.title, use_markup: false, activatable: true, focusable: true);

            this.job = job;
            update_property (
                Gtk.AccessibleProperty.LABEL, job.tool.title,
                Gtk.AccessibleProperty.DESCRIPTION, job.displayed_title, -1
            );

            var title_label = new Gtk.Label (job.tool.title) {
                xalign = 0,
                hexpand = true,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                lines = 2,
                ellipsize = Pango.EllipsizeMode.END,
                css_classes = { "heading" },
                tooltip_text = job.tool.title
            };

            var version_label = new Gtk.Label (job.displayed_title) {
                xalign = 0,
                ellipsize = Pango.EllipsizeMode.END,
                css_classes = { "caption", "dim-label" },
                tooltip_text = job.displayed_title
            };

            var labels_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                hexpand = true
            };
            labels_box.append (title_label);
            labels_box.append (version_label);

            progress_bar = new Gtk.ProgressBar () {
                show_text = false
            };

            status_label = new Gtk.Label ("") {
                xalign = 0,
                css_classes = { "caption" },
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR
            };

            metrics_label = new Gtk.Label ("") {
                xalign = 0,
                css_classes = { "caption" },
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR
            };

            var progress_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            progress_box.append (progress_bar);
            progress_box.append (status_label);
            progress_box.append (metrics_label);

            cancel_button = new Gtk.Button.from_icon_name ("process-stop-symbolic") {
                valign = Gtk.Align.START
            };
            cancel_button.add_css_class ("flat");
            cancel_button.set_tooltip_text (_("Cancel"));
            cancel_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Cancel"), -1
            );
            cancel_button.clicked.connect (cancel);

            var heading = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            heading.append (labels_box);
            heading.append (cancel_button);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };
            content.append (heading);
            content.append (progress_box);
            set_child (content);

            progress_handler = job.progress_updated.connect (update_display);
            step_handler = job.notify["step"].connect (update_display);
            canceled_handler = job.notify["canceled"].connect (update_display);
            update_display ();
        }

        public override void dispose () {
            disconnect_release_signals ();
            base.dispose ();
        }

        public void disconnect_release_signals () {
            if (progress_handler != 0) {
                job.disconnect (progress_handler);
                progress_handler = 0;
            }

            if (step_handler != 0) {
                job.disconnect (step_handler);
                step_handler = 0;
            }

            if (canceled_handler != 0) {
                job.disconnect (canceled_handler);
                canceled_handler = 0;
            }
        }

        private void cancel () {
            job.canceled = true;
            update_display ();
        }

        private void update_display () {
            var step_text = get_step_text ();
            var progress_text = job.progress ?? "";

            if (job.is_percent && job.progress != null) {
                var value = job.progress.replace ("%", "");
                progress_bar.fraction = double.parse (value) / 100.0;
            } else {
                progress_bar.fraction = 0.0;
            }

            if (job.canceled) {
                step_text = _("Cancelling");
                cancel_button.set_sensitive (false);
                cancel_button.set_tooltip_text (_("Cancelling"));
                cancel_button.update_property (
                    Gtk.AccessibleProperty.LABEL, _("Cancelling"), -1
                );
            }

            var status = step_text;
            if (progress_text != "")
                status += " · %s".printf (progress_text);

            var speed = "--";
            if (job.step == Services.InstallJob.Step.DOWNLOADING) {
                speed = "%s/s".printf (format_size (
                    (int64) (job.speed_kbps * 1024)
                ));
            }

            status_label.set_label (status);
            status_label.set_tooltip_text (status);
            var seconds = job.step == Services.InstallJob.Step.DOWNLOADING ? job.seconds_remaining : -1;
            var eta = format_eta (seconds);
            var eta_description = seconds >= 0
                ? _("Remaining time: %s").printf (eta) : _("Remaining time: --");
            metrics_label.set_label ("%s · %s".printf (speed, eta));
            metrics_label.set_tooltip_text (eta_description);
            metrics_label.update_property (
                Gtk.AccessibleProperty.LABEL, "%s · %s".printf (speed, eta_description), -1
            );
        }

        private string get_step_text () {
            switch (job.step) {
                case Services.InstallJob.Step.DOWNLOADING:
                    return job.download_status;
                case Services.InstallJob.Step.CHECKING_RELEASE:
                    return _("Checking for a release");
                case Services.InstallJob.Step.EXTRACTING:
                    return _("Extracting");
                case Services.InstallJob.Step.MOVING:
                    return _("Installing");
                case Services.InstallJob.Step.FINALIZING:
                    return _("Finalizing the update");
                case Services.InstallJob.Step.REMOVING:
                    return _("Removing");
                default:
                    return _("Preparing");
            }
        }

        private string format_eta (double seconds) {
            if (seconds < 0)
                return "--";

            var total_seconds = (int) seconds;
            var hours = total_seconds / 3600;
            var minutes = (total_seconds % 3600) / 60;
            var remaining_seconds = total_seconds % 60;

            if (hours > 0)
                return _("%dh %dm %ds").printf (hours, minutes, remaining_seconds);
            if (minutes > 0)
                return _("%dm %ds").printf (minutes, remaining_seconds);
            return _("%ds").printf (remaining_seconds);
        }
    }
}
