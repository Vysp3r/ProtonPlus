namespace ProtonPlus.Widgets.Tools {
    public class ReleaseRow : Adw.ActionRow {
        public signal void job_selected (Services.InstallJob job);

        protected Services.InstallJob job { get; set; }
        Gtk.Button update_button { get; set; }
        Gtk.Button open_button { get; set; }
        Gtk.Button remove_button { get; set; }
        Gtk.Button install_button { get; set; }
        Gtk.Button cancel_button { get; set; }
        Gtk.Button progress_button { get; set; }
        Widgets.CircularProgressBar progress_bar { get; set; }
        Gtk.Label step_label { get; set; }
        Gtk.Label speed_label { get; set; }
        Gtk.Label time_label { get; set; }
        Gtk.Label usage_pill { get; set; }
        Gtk.Popover info_popover { get; set; }
        uint progress_pulse_timeout_id = 0;

        public ReleaseRow (Services.InstallJob job) {
            Object (title: job.title, subtitle: job.release.release_date, activatable: true);
            this.job = job;
            var icon = new Gtk.Image.from_icon_name ("box-open-symbolic");
            remove_button = new Gtk.Button.from_icon_name ("trash-symbolic");
            remove_button.set_tooltip_text (_("Delete %s").printf (job.title));
            remove_button.add_css_class ("flat");
            remove_button.clicked.connect (remove_button_clicked);
            create_install_btn ();
            cancel_button = new Gtk.Button.from_icon_name ("circle-xmark-symbolic");
            cancel_button.set_tooltip_text (_("Cancel installation"));
            cancel_button.add_css_class ("flat");
            cancel_button.clicked.connect (() => { job.canceled = true; });
            progress_bar = new Widgets.CircularProgressBar () { valign = Gtk.Align.CENTER, show_text = true };
            progress_bar.set_size_request (24, 24);
            progress_bar.line_width = 2;
            progress_button = new Gtk.Button ();
            progress_button.set_child (progress_bar);
            progress_button.add_css_class ("flat");
            progress_button.set_tooltip_text (_("Show installation details"));
            progress_button.clicked.connect (() => { info_popover.popup (); });
            step_label = new Gtk.Label ("") { halign = Gtk.Align.START };
            speed_label = new Gtk.Label (_("Speed: 0 KB/s")) { halign = Gtk.Align.START };
            time_label = new Gtk.Label (_("Remaining time: --")) { halign = Gtk.Align.START };
            var info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) { margin_top = 12, margin_bottom = 12, margin_start = 12, margin_end = 12 };
            info_box.append (step_label); info_box.append (speed_label); info_box.append (time_label);
            info_popover = new Gtk.Popover (); info_popover.set_parent (progress_button); info_popover.set_autohide (true); info_popover.set_child (info_box);
            activated.connect (() => job_selected (job));
            var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { margin_end = 12, valign = Gtk.Align.CENTER };
            input_box.add_css_class ("linked"); input_box.add_css_class ("tools-release-row-input-box");
            if (job.mode == Services.InstallJob.Mode.LATEST || job.tinker_game_context != null) {
                update_button = new Gtk.Button.from_icon_name ("arrows-rotate-symbolic");
                update_button.add_css_class ("flat");
                update_button.set_tooltip_text (_("Update the runner if a newer version is available"));
                update_button.clicked.connect (update_button_clicked);
                input_box.append (update_button);
                var info_pill = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { valign = Gtk.Align.CENTER, margin_end = 6 };
                info_pill.append (new Gtk.Image.from_icon_name ("info-2-symbolic"));
                info_pill.set_tooltip_text (_("Version: %s\nThis is a rolling release.\nIt will always be updated to the latest available version when automatic updates is activated.").printf (job.tool.last_version));
                info_pill.add_css_class ("info-pill"); add_suffix (info_pill);
            }
            open_button = new Gtk.Button.from_icon_name ("folder-open-2-symbolic");
            open_button.set_tooltip_text (_("Open tool directory")); open_button.add_css_class ("flat"); open_button.clicked.connect (open_button_clicked);
            input_box.append (open_button); input_box.append (remove_button); input_box.append (install_button); input_box.append (progress_button); input_box.append (cancel_button);
            usage_pill = new Gtk.Label ("") { valign = Gtk.Align.CENTER, margin_end = 6 }; usage_pill.add_css_class ("usage-pill"); add_suffix (usage_pill);
            refresh_usage_pill (); add_prefix (icon); add_suffix (input_box);
            job.notify["state"].connect (job_state_changed); job.notify["step"].connect (job_step_changed); job.progress_updated.connect (job_progress_changed);
            job.notify_property ("step"); job.notify_property ("state");
        }

        void create_install_btn () {
            install_button = new Gtk.Button.from_icon_name ("download-2-symbolic"); install_button.set_tooltip_text (_("Install %s").printf (job.title)); install_button.add_css_class ("flat"); install_button.clicked.connect (install_button_clicked);
        }
        public override void dispose () { stop_progress_pulse (); info_popover.unparent (); base.dispose (); }
        void job_state_changed () {
            var installed = job.state == Services.InstallJob.State.UP_TO_DATE || job.state == Services.InstallJob.State.UPDATE_AVAILABLE;
            var downloading = job.state == Services.InstallJob.State.BUSY_INSTALLING || job.state == Services.InstallJob.State.BUSY_UPDATING;
            var busy = downloading || job.state == Services.InstallJob.State.BUSY_REMOVING;
            install_button.set_visible (!installed && !downloading); progress_button.set_visible (downloading); cancel_button.set_visible (downloading); remove_button.set_visible (installed); update_button?.set_visible (installed); open_button.set_visible (installed);
            install_button.set_sensitive (!busy); remove_button.set_sensitive (!busy); update_button?.set_sensitive (!busy); open_button.set_sensitive (!busy); update_progress_pulse ();
        }
        void job_step_changed () {
            progress_bar.show_text = job.step == Services.InstallJob.Step.DOWNLOADING; speed_label.set_visible (job.step == Services.InstallJob.Step.DOWNLOADING); time_label.set_visible (job.step == Services.InstallJob.Step.DOWNLOADING); update_progress_pulse ();
            string text = _("Nothing");
            switch (job.step) { case Services.InstallJob.Step.DOWNLOADING: text = _("Downloading"); break; case Services.InstallJob.Step.EXTRACTING: text = _("Extracting"); break; case Services.InstallJob.Step.MOVING: text = _("Moving"); break; case Services.InstallJob.Step.REMOVING: text = _("Removing"); break; default: break; }
            step_label.set_label (_("Step: %s").printf (text));
        }
        void update_progress_pulse () {
            var installing = job.state == Services.InstallJob.State.BUSY_INSTALLING || job.state == Services.InstallJob.State.BUSY_UPDATING;
            var needs_pulse = installing && (job.step == Services.InstallJob.Step.EXTRACTING || job.step == Services.InstallJob.Step.MOVING);
            if (needs_pulse && progress_pulse_timeout_id == 0) { progress_bar.pulse (0.01); progress_pulse_timeout_id = Timeout.add (16, () => { progress_bar.pulse (0.01); return Source.CONTINUE; }); } else if (!needs_pulse) stop_progress_pulse ();
        }
        void stop_progress_pulse () { if (progress_pulse_timeout_id != 0) { Source.remove (progress_pulse_timeout_id); progress_pulse_timeout_id = 0; } }
        void update_button_clicked () {
            job.update.begin ((obj, res) => { var code = job.update.end (res); if (code == ReturnCode.RUNNER_UPDATED) Utils.DownloadManager.instance.tool_updated (job, true); else if (code == ReturnCode.NOTHING_TO_UPDATE) Utils.DownloadManager.instance.tool_updated (job, false); else if (!job.canceled) show_error (_("Failed to Update %s").printf (job.title), _("An error occurred while attempting to update the compatibility tool."), code); });
        }
        void open_button_clicked () { Utils.System.open_uri ("file://%s".printf (job.install_location)); }
        public void refresh_usage_pill () { var count = job.tool.group.launcher.get_compatibility_tool_usage_count (job.usage_name); if (count > 0) { usage_pill.set_label (count.to_string ()); usage_pill.set_tooltip_text (ngettext ("Used by %i game", "Used by %i games", count).printf (count)); usage_pill.set_visible (true); } else usage_pill.set_visible (false); }
        void job_progress_changed () { if (job.is_percent && job.progress != null) progress_bar.fraction = double.parse (job.progress.replace ("%", "")) / 100.0; else progress_bar.pulse (); speed_label.set_label (_("Speed: %s/s").printf (Utils.Filesystem.convert_bytes_to_string ((int64) (job.speed_kbps * 1024)))); time_label.set_label (job.seconds_remaining >= 0 ? _("Remaining time: %s").printf (format_time (job.seconds_remaining)) : _("Remaining time: --")); }
        string format_time (double seconds) { int total = (int) seconds; int h = total / 3600; int m = (total % 3600) / 60; int s = total % 60; return h > 0 ? _("%dh %dm %ds").printf (h, m, s) : m > 0 ? _("%dm %ds").printf (m, s) : _("%ds").printf (s); }
        protected virtual void install_button_clicked () { job.install.begin ((obj, res) => { var code = job.install.end (res); if (code != ReturnCode.RUNNER_INSTALLED && !job.canceled) show_error (_("Installation Failed"), _("ProtonPlus could not install %s on your system.").printf (job.title), code); }); }
        protected virtual void remove_button_clicked () { var dialog = new RemoveDialog (job); customize_remove_dialog (dialog); ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ()); }
        protected virtual void customize_remove_dialog (RemoveDialog dialog) {}
        private void show_error (string title, string description, ReturnCode code) { var dialog = new Main.ErrorDialog (title, description, job.error_message ?? get_return_code_message (code)); ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ()); }
    }
}
