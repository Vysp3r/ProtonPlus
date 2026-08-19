namespace ProtonPlus.Widgets.Tools {
    public class ReleaseRow : Adw.ActionRow, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler, ReleaseRowJobSignalTarget {
        private enum ControllerFocusLane {
            ROW,
            PRIMARY_ACTION,
            MORE_ACTIONS
        }

        public signal void changelog_requested (Services.InstallJob job);
        public signal void games_requested (Services.InstallJob job);

        protected Services.InstallJob job { get; set; }
        protected bool action_request_in_progress { get; private set; default = false; }
        protected bool row_disposed { get; private set; default = false; }
        protected ReleaseRowRetryAction retry_action { get; private set; default = ReleaseRowRetryAction.NONE; }

        Gtk.Box input_box;
        Gtk.Button primary_button;
        Adw.ButtonContent primary_content;
        Gtk.Button cancel_button;
        Gtk.Button progress_button;
        Widgets.CircularProgressBar progress_bar;
        Gtk.Label progress_status_label;
        Gtk.Label step_label;
        Gtk.Label speed_label;
        Gtk.Label time_label;
        Gtk.Popover info_popover;
        Gtk.MenuButton actions_button;
        Gtk.PopoverMenu actions_popover;
        Gtk.SizeGroup action_button_size_group;
        SimpleAction update_action;
        SimpleAction changelog_action;
        SimpleAction games_action;
        SimpleAction open_release_page_action;
        SimpleAction open_folder_action;
        SimpleAction delete_action;
        weak Gtk.Widget? controller_up_target;
        weak Gtk.Widget? controller_row_up_target;
        weak Gtk.Widget? controller_action_up_target;
        weak Gtk.Widget? controller_down_target;

        ReleaseRowJobSignalBinding job_signal_binding;
        uint progress_pulse_timeout_id = 0;
        bool release_action_available;
        string? operation_error_message = null;

        public ReleaseRow (
            Services.InstallJob job,
            bool release_action_available = true
        ) {
            Object (
                title: release_display_title (job),
                subtitle: release_display_timestamp (job),
                subtitle_lines: 1,
                title_lines: 1,
                activatable: true
            );
            this.job = job;
            this.release_action_available = release_action_available;
            add_css_class ("tools-release-row");

            activated.connect (request_release_details);

            create_primary_button ();
            create_progress_button ();
            create_cancel_button ();
            create_actions_menu ();

            action_button_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);
            action_button_size_group.add_widget (primary_button);
            action_button_size_group.add_widget (actions_button);

            input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                margin_end = 12,
                valign = Gtk.Align.CENTER
            };
            input_box.add_css_class ("tools-release-row-input-box");
            input_box.append (primary_button);
            input_box.append (progress_button);
            input_box.append (cancel_button);
            input_box.append (actions_button);
            add_suffix (input_box);

            job_signal_binding = new ReleaseRowJobSignalBinding (job, this);

            refresh_presentation ();
            release_row_job_step_changed ();
            release_row_job_progress_changed ();
        }

        void create_primary_button () {
            primary_content = new Adw.ButtonContent () {
                can_shrink = true
            };
            primary_button = new Gtk.Button () {
                child = primary_content,
                valign = Gtk.Align.CENTER
            };
            primary_button.add_css_class ("flat");
            primary_button.add_css_class ("tools-release-install-button");
            primary_button.clicked.connect (primary_button_clicked);
        }

        void create_progress_button () {
            progress_bar = new Widgets.CircularProgressBar () {
                valign = Gtk.Align.CENTER,
                show_text = true,
                line_width = 2,
                accessible_role = Gtk.AccessibleRole.PROGRESS_BAR
            };
            progress_bar.set_size_request (24, 24);
            progress_bar.update_property (
                Gtk.AccessibleProperty.VALUE_MIN, 0.0,
                Gtk.AccessibleProperty.VALUE_MAX, 100.0,
                -1
            );

            progress_status_label = new Gtk.Label ("") {
                valign = Gtk.Align.CENTER,
                accessible_role = Gtk.AccessibleRole.STATUS,
                ellipsize = Pango.EllipsizeMode.END,
                width_chars = 12,
                max_width_chars = 12
            };
            var progress_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            progress_content.append (progress_bar);
            progress_content.append (progress_status_label);

            progress_button = new Gtk.Button () {
                child = progress_content,
                valign = Gtk.Align.CENTER
            };
            progress_button.add_css_class ("flat");
            progress_button.set_tooltip_text (_("Show installation details"));
            progress_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Show installation details"), -1
            );
            progress_button.clicked.connect (progress_button_clicked);

            step_label = new Gtk.Label ("") { halign = Gtk.Align.START };
            speed_label = new Gtk.Label (_("Speed: 0 KB/s")) {
                halign = Gtk.Align.START
            };
            time_label = new Gtk.Label (_("Remaining time: --")) {
                halign = Gtk.Align.START
            };
            var info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };
            info_box.append (step_label);
            info_box.append (speed_label);
            info_box.append (time_label);

            info_popover = new Gtk.Popover ();
            info_popover.set_parent (progress_button);
            info_popover.set_autohide (true);
            info_popover.set_child (info_box);
            Window.register_popover_for_controller (
                info_popover, progress_button, step_label
            );
        }

        void create_cancel_button () {
            cancel_button = new Gtk.Button.with_label (_("Cancel")) {
                valign = Gtk.Align.CENTER
            };
            cancel_button.add_css_class ("flat");
            cancel_button.clicked.connect (cancel_button_clicked);
        }

        void create_actions_menu () {
            var action_group = new SimpleActionGroup ();
            changelog_action = new SimpleAction ("changelog", null);
            changelog_action.activate.connect (changelog_action_activated);
            action_group.add_action (changelog_action);
            games_action = new SimpleAction ("games", null);
            games_action.activate.connect (games_action_activated);
            action_group.add_action (games_action);
            open_release_page_action = new SimpleAction (
                "open-release-page", null
            );
            open_release_page_action.activate.connect (
                open_release_page_action_activated
            );
            action_group.add_action (open_release_page_action);
            update_action = new SimpleAction ("update", null);
            update_action.activate.connect (update_action_activated);
            action_group.add_action (update_action);
            open_folder_action = new SimpleAction ("open-folder", null);
            open_folder_action.activate.connect (open_folder_action_activated);
            action_group.add_action (open_folder_action);
            delete_action = new SimpleAction ("delete", null);
            delete_action.activate.connect (delete_action_activated);
            action_group.add_action (delete_action);
            actions_button = new Gtk.MenuButton () {
                icon_name = "view-more-symbolic",
                valign = Gtk.Align.CENTER
            };
            actions_button.insert_action_group ("release", action_group);
            actions_button.set_has_frame (false);
            actions_button.add_css_class ("flat");
            actions_button.set_tooltip_text (_("Release Actions"));
            actions_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Actions for %s").printf (job.title),
                -1
            );

            actions_popover = new Gtk.PopoverMenu.from_model (new Menu ());
            actions_popover.closed.connect (actions_popover_closed);
            actions_popover.map.connect (actions_popover_mapped);
            actions_button.set_popover (actions_popover);
            Window.register_popover_for_controller (actions_popover, actions_button);
        }

        void changelog_action_activated (Variant? parameter) {
            request_release_details ();
        }

        void request_release_details () {
            if (!row_disposed)
                changelog_requested (job);
        }

        void games_action_activated (Variant? parameter) {
            games_requested (job);
        }

        void open_release_page_action_activated (Variant? parameter) {
            if (action_request_in_progress || row_disposed ||
                job.release.page_url == null)
                return;
            Utils.System.open_uri (job.release.page_url);
        }

        void progress_button_clicked () {
            if (info_popover.get_mapped ())
                info_popover.popdown ();
            else
                info_popover.popup ();
        }

        void cancel_button_clicked () {
            if (!is_busy_state (job.state) || job.canceled)
                return;
            job.canceled = true;
        }

        void update_action_activated (Variant? parameter) {
            request_update ();
        }

        void open_folder_action_activated (Variant? parameter) {
            open_folder ();
        }

        void delete_action_activated (Variant? parameter) {
            request_removal ();
        }

        void actions_popover_closed () {
            if (!row_disposed && actions_button.get_mapped () &&
                actions_button.is_visible () && actions_button.is_sensitive ())
                actions_button.grab_focus ();
        }

        void actions_popover_mapped () {
            focus_actions_popover_when_mapped (this);
        }

        static void focus_actions_popover_when_mapped (ReleaseRow owner) {
            var owner_ref = WeakRef (owner);
            Idle.add (() => {
                var row = owner_ref.get () as ReleaseRow;
                if (row != null && !((!) row).row_disposed &&
                    ((!) row).actions_popover.get_mapped ()) {
                    ((!) row).actions_popover.child_focus (
                        Gtk.DirectionType.TAB_FORWARD
                    );
                }
                return Source.REMOVE;
            });
        }

        public void set_controller_up_targets (
            Gtk.Widget? fallback_target,
            Gtk.Widget? row_target,
            Gtk.Widget? action_target
        ) {
            controller_up_target = fallback_target;
            controller_row_up_target = row_target;
            controller_action_up_target = action_target;
        }

        public void set_controller_down_target (Gtk.Widget? target) {
            controller_down_target = target;
        }

        public bool controller_focus_direction (
            Object focused_object,
            Utils.ControllerNavigationDirection direction
        ) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;

            if (direction == Utils.ControllerNavigationDirection.UP ||
                direction == Utils.ControllerNavigationDirection.DOWN)
                return focus_vertical ((!) focused, direction);

            if (direction == Utils.ControllerNavigationDirection.LEFT ||
                direction == Utils.ControllerNavigationDirection.RIGHT)
                return focus_horizontal ((!) focused, direction);

            return false;
        }

        public bool controller_activate (Object focused_object) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;

            var action = find_action_ancestor ((!) focused);
            if (action == actions_button) {
                actions_button.popup ();
                return true;
            }
            if (action != null)
                return ((!) action).activate ();

            request_release_details ();
            return true;
        }

        bool focus_vertical (
            Gtk.Widget focused,
            Utils.ControllerNavigationDirection direction
        ) {
            var focus_lane = controller_focus_lane (focused);
            var adjacent = find_adjacent_release (direction);
            if (adjacent != null)
                return ((!) adjacent).focus_controller_lane (focus_lane);

            if (direction == Utils.ControllerNavigationDirection.UP) {
                var preferred_target = focus_lane != ControllerFocusLane.ROW
                    ? controller_action_up_target
                    : controller_row_up_target;
                if (focus_controller_target (preferred_target))
                    return true;
                return focus_controller_target (controller_up_target);
            }

            if (focus_next_list_control ())
                return true;

            return controller_down_target != null &&
                ((!) controller_down_target).get_mapped () &&
                ((!) controller_down_target).is_visible () &&
                ((!) controller_down_target).is_sensitive () &&
                ((!) controller_down_target).grab_focus ();
        }

        ControllerFocusLane controller_focus_lane (Gtk.Widget focused) {
            var action = find_action_ancestor (focused);
            if (action == actions_button)
                return ControllerFocusLane.MORE_ACTIONS;
            if (action != null)
                return ControllerFocusLane.PRIMARY_ACTION;
            return ControllerFocusLane.ROW;
        }

        bool focus_controller_lane (ControllerFocusLane lane) {
            switch (lane) {
            case ControllerFocusLane.PRIMARY_ACTION:
                var primary_action = find_focusable_primary_action ();
                if (focus_controller_target (primary_action))
                    return true;
                break;
            case ControllerFocusLane.MORE_ACTIONS:
                if (focus_controller_target (actions_button))
                    return true;
                break;
            default:
                break;
            }
            return grab_focus ();
        }

        public bool focus_more_actions_controller_target () {
            return focus_controller_lane (ControllerFocusLane.MORE_ACTIONS);
        }

        Gtk.Widget? find_focusable_primary_action () {
            var action = find_focusable_action (null, true);
            return action != actions_button ? action : null;
        }

        bool focus_controller_target (Gtk.Widget? target) {
            return target != null && ((!) target).get_mapped () &&
                ((!) target).is_visible () && ((!) target).is_sensitive () &&
                ((!) target).grab_focus ();
        }

        ReleaseRow? find_adjacent_release (
            Utils.ControllerNavigationDirection direction
        ) {
            Gtk.Widget? sibling = direction == Utils.ControllerNavigationDirection.UP
                ? get_prev_sibling () : get_next_sibling ();
            while (sibling != null) {
                if (sibling is ReleaseRow && sibling.get_mapped () &&
                    sibling.is_visible () && sibling.get_child_visible () &&
                    sibling.is_sensitive () && sibling.get_focusable ())
                    return (ReleaseRow) sibling;
                sibling = direction == Utils.ControllerNavigationDirection.UP
                    ? sibling.get_prev_sibling () : sibling.get_next_sibling ();
            }
            return null;
        }

        bool focus_next_list_control () {
            var sibling = get_next_sibling ();
            while (sibling != null) {
                if (sibling.get_mapped () && sibling.is_visible () &&
                    sibling.get_child_visible () && sibling.is_sensitive ())
                    return sibling.child_focus (Gtk.DirectionType.TAB_FORWARD) ||
                        sibling.grab_focus ();
                sibling = sibling.get_next_sibling ();
            }
            return false;
        }

        bool focus_horizontal (
            Gtk.Widget focused,
            Utils.ControllerNavigationDirection direction
        ) {
            var action = find_action_ancestor (focused);
            if (direction == Utils.ControllerNavigationDirection.RIGHT) {
                if (focused == this)
                    return focus_first_action ();
                if (action != null)
                    return focus_action_sibling ((!) action, true);
            } else {
                if (focused == this)
                    return grab_focus ();
                if (action != null)
                    return grab_focus ();
            }
            return false;
        }

        bool focus_first_action () {
            var action = find_focusable_action (null, true);
            return action != null ? ((!) action).grab_focus () : grab_focus ();
        }

        bool focus_action_sibling (Gtk.Widget action, bool forward) {
            var sibling = find_focusable_action (action, forward);
            return sibling != null
                ? ((!) sibling).grab_focus ()
                : action.grab_focus ();
        }

        Gtk.Widget? find_focusable_action (Gtk.Widget? current, bool forward) {
            Gtk.Widget? child;
            if (current == null)
                child = forward
                    ? input_box.get_first_child ()
                    : input_box.get_last_child ();
            else
                child = forward
                    ? current.get_next_sibling ()
                    : current.get_prev_sibling ();

            while (child != null) {
                if (child.get_mapped () && child.is_visible () &&
                    child.is_sensitive () && child.get_can_focus ())
                    return child;
                child = forward
                    ? child.get_next_sibling ()
                    : child.get_prev_sibling ();
            }
            return null;
        }

        Gtk.Widget? find_action_ancestor (Gtk.Widget focused) {
            Gtk.Widget? current = focused;
            while (current != null && current != input_box) {
                if (current.get_parent () == input_box)
                    return current;
                current = current.get_parent ();
            }
            return null;
        }

        public override void dispose () {
            row_disposed = true;
            job_signal_binding.disconnect_handlers ();
            stop_progress_pulse ();
            info_popover.popdown ();
            actions_button.popdown ();
            actions_button.set_popover (null);
            actions_button.insert_action_group ("release", null);
            if (info_popover.get_parent () != null)
                info_popover.unparent ();
            base.dispose ();
        }

        public void release_row_job_state_changed () {
            if (row_disposed)
                return;
            refresh_presentation ();
        }

        public void release_row_job_step_changed () {
            if (row_disposed)
                return;

            var downloading = job.step == Services.InstallJob.Step.DOWNLOADING;
            progress_bar.show_text = downloading;
            speed_label.set_visible (downloading);
            time_label.set_visible (downloading);

            var operation_text = operation_step_text ();
            progress_status_label.set_label (operation_text);
            step_label.set_label (_("Step: %s").printf (operation_text));
            progress_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("%s for %s").printf (operation_text, job.title),
                -1
            );
            progress_bar.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Progress for %s").printf (job.title),
                Gtk.AccessibleProperty.VALUE_TEXT,
                operation_text,
                -1
            );

            refresh_presentation ();
        }

        public void release_row_job_canceled_changed () {
            if (row_disposed)
                return;
            if (job.canceled)
                progress_status_label.set_label (_("Cancelling"));
            refresh_presentation ();
        }

        public void release_row_job_variant_changed () {
            if (row_disposed)
                return;
            retry_action = ReleaseRowRetryAction.NONE;
            operation_error_message = null;
            refresh_presentation ();
        }

        public void release_row_job_release_changed () {
            if (row_disposed)
                return;
            set_title (release_display_title (job));
            retry_action = ReleaseRowRetryAction.NONE;
            operation_error_message = null;
            actions_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Actions for %s").printf (job.title),
                -1
            );
            refresh_presentation ();
        }

        ReleaseRowPresentation current_presentation () {
            var has_directory = job.install_location != "" &&
                FileUtils.test (job.install_location, FileTest.IS_DIR);
            return ReleaseRowPresentation.evaluate (
                job.state,
                job.step,
                supports_update_check (),
                has_directory,
                job.canceled,
                job.mode != Services.InstallJob.Mode.VERSIONED,
                usage_count () > 0,
                release_action_available,
                retry_action
            );
        }

        public static string release_display_title (Services.InstallJob job) {
            if (job.steam_tinker_launch_context != null)
                return _("Latest");
            var title = job.release.title != "" ? job.release.title : job.title;
            return job.mode == Services.InstallJob.Mode.LATEST
                ? _("Latest")
                : title;
        }

        public static string release_display_timestamp (Services.InstallJob job) {
            return job.mode == Services.InstallJob.Mode.VERSIONED
                ? Utils.format_timestamp (job.release.release_date)
                : "";
        }

        public void set_release_action_available (bool available) {
            if (release_action_available == available)
                return;
            release_action_available = available;
            retry_action = ReleaseRowRetryAction.NONE;
            if (!row_disposed)
                refresh_presentation ();
        }

        bool supports_update_check () {
            return job.mode == Services.InstallJob.Mode.LATEST ||
                job.steam_tinker_launch_context != null;
        }

        int usage_count () {
            return job.tool.group.launcher.get_compatibility_tool_usage_count (
                job.get_usage_identifier ()
            );
        }

        void refresh_presentation () {
            var focused = get_focused_widget ();
            var replace_focus = focused != null &&
                (focused == input_box || ((!) focused).is_ancestor (input_box) ||
                 focused == actions_popover || ((!) focused).is_ancestor (actions_popover));
            var presentation = current_presentation ();

            configure_primary_action (presentation.primary_action);
            primary_button.set_visible (
                presentation.primary_action == ReleaseRowPrimaryAction.INSTALL ||
                presentation.primary_action == ReleaseRowPrimaryAction.RETRY
            );
            primary_button.set_sensitive (!action_request_in_progress);
            progress_button.set_visible (
                presentation.primary_action == ReleaseRowPrimaryAction.PROGRESS
            );
            cancel_button.set_visible (presentation.show_cancel);
            cancel_button.set_sensitive (presentation.cancel_enabled);
            update_cancel_accessibility ();
            rebuild_actions_menu (presentation);
            update_progress_pulse (presentation);
            refresh_status_text ();

            if (replace_focus && !is_valid_focus_target (focused))
                focus_replacement ();
        }

        void configure_primary_action (ReleaseRowPrimaryAction action) {
            switch (action) {
            case ReleaseRowPrimaryAction.INSTALL:
                primary_content.set_icon_name ("folder-download-symbolic");
                primary_content.set_label ("");
                primary_button.set_tooltip_text (_("Install %s").printf (job.title));
                primary_button.update_property (
                    Gtk.AccessibleProperty.LABEL,
                    _("Install %s").printf (job.title),
                    -1
                );
                break;
            case ReleaseRowPrimaryAction.RETRY:
                primary_content.set_icon_name ("view-refresh-symbolic");
                primary_content.set_label (_("Retry"));
                primary_button.set_tooltip_text (_("Retry %s").printf (get_title ()));
                primary_button.update_property (
                    Gtk.AccessibleProperty.LABEL,
                    _("Retry %s").printf (get_title ()),
                    -1
                );
                break;
            default:
                break;
            }
        }

        void update_cancel_accessibility () {
            var label = job.canceled
                ? _("Cancelling %s").printf (job.title)
                : _("Cancel %s").printf (job.title);
            cancel_button.set_tooltip_text (label);
            cancel_button.update_property (
                Gtk.AccessibleProperty.LABEL, label, -1
            );
        }

        void rebuild_actions_menu (ReleaseRowPresentation presentation) {
            changelog_action.set_enabled (!action_request_in_progress);
            games_action.set_enabled (!action_request_in_progress);
            open_release_page_action.set_enabled (
                job.release.page_url != null && !action_request_in_progress
            );
            update_action.set_enabled (
                presentation.show_update_action && !action_request_in_progress
            );
            open_folder_action.set_enabled (
                presentation.show_open_folder && !action_request_in_progress
            );
            delete_action.set_enabled (
                presentation.show_delete && !action_request_in_progress
            );

            var menu = new Menu ();
            var details_section = new Menu ();
            details_section.append (_("_Changelog"), "release.changelog");
            if (job.release.page_url != null) {
                details_section.append (
                    _("Open Release Page"), "release.open-release-page"
                );
            }
            if (job.tool.group.launcher is Models.Launchers.Steam) {
                details_section.append (
                    _("_Games Using This Tool"), "release.games"
                );
            }
            menu.append_section (null, details_section);

            var management_section = new Menu ();
            if (presentation.show_update_action) {
                var label = retry_action == ReleaseRowRetryAction.UPDATE
                    ? _("Retry")
                    : presentation.update_available
                        ? _("Update")
                        : _("_Check for Updates");
                management_section.append (label, "release.update");
            }
            if (presentation.show_open_folder)
                management_section.append (_("_Open Folder"), "release.open-folder");
            if (presentation.show_delete)
                management_section.append (_("_Delete…"), "release.delete");
            if (management_section.get_n_items () > 0)
                menu.append_section (null, management_section);
            actions_popover.set_menu_model (menu);

            actions_button.set_visible (presentation.show_menu);
            actions_button.set_sensitive (
                presentation.show_menu && !action_request_in_progress
            );
            if (!presentation.show_menu)
                actions_button.popdown ();
        }

        Gtk.Widget? get_focused_widget () {
            var root = get_root () as Gtk.Root;
            return root?.get_focus ();
        }

        bool is_valid_focus_target (Gtk.Widget? widget) {
            return widget != null && ((!) widget).get_root () != null &&
                ((!) widget).get_mapped () && ((!) widget).is_visible () &&
                ((!) widget).is_sensitive () && ((!) widget).get_focusable ();
        }

        void focus_replacement () {
            var replacement = find_focusable_action (null, true);
            if (replacement != null)
                ((!) replacement).grab_focus ();
            else
                grab_focus ();
        }

        void refresh_status_text () {
            var details = new Gee.ArrayList<string> ();
            var presentation = current_presentation ();
            if (presentation.recommended)
                details.add (_("Recommended"));
            if (retry_action != ReleaseRowRetryAction.NONE)
                details.add (_("Failed"));
            if (operation_error_message != null)
                details.add ((!) operation_error_message);
            switch (job.state) {
            case Services.InstallJob.State.NOT_INSTALLED:
                break;
            case Services.InstallJob.State.UPDATE_AVAILABLE:
                details.add (_("Installed"));
                details.add (_("Update available"));
                break;
            case Services.InstallJob.State.UP_TO_DATE:
                details.add (_("Installed"));
                break;
            case Services.InstallJob.State.BUSY_INSTALLING:
                details.add (_("Installing"));
                details.add (operation_step_text ());
                break;
            case Services.InstallJob.State.BUSY_UPDATING:
                details.add (_("Updating"));
                details.add (operation_step_text ());
                break;
            case Services.InstallJob.State.BUSY_REMOVING:
                details.add (_("Removing"));
                break;
            }

            if (presentation.unavailable)
                details.add (_("Unavailable for the selected variant"));

            var current_usage_count = usage_count ();
            if (presentation.in_use) {
                details.add (ngettext (
                    "In use by %i game", "In use by %i games", current_usage_count
                ).printf (current_usage_count));
            }

            var status = string.joinv (" · ", details.to_array ());
            var date = release_display_timestamp (job);
            set_subtitle (
                date != "" && status != ""
                    ? "%s · %s".printf (date, status)
                    : date != "" ? date : status
            );
            update_property (
                Gtk.AccessibleProperty.DESCRIPTION,
                status != ""
                    ? _("%s. Open Release Details").printf (status)
                    : _("Open Release Details"),
                -1
            );
        }

        string operation_step_text () {
            if (job.canceled)
                return _("Cancelling");
            switch (job.step) {
            case Services.InstallJob.Step.DOWNLOADING:
                return _("Downloading");
            case Services.InstallJob.Step.EXTRACTING:
                return _("Extracting");
            case Services.InstallJob.Step.MOVING:
                return _("Moving");
            case Services.InstallJob.Step.REMOVING:
                return _("Removing");
            default:
                if (job.state == Services.InstallJob.State.BUSY_UPDATING)
                    return _("Preparing update");
                if (job.state == Services.InstallJob.State.BUSY_REMOVING)
                    return _("Removing");
                return _("Preparing installation");
            }
        }

        void update_progress_pulse (ReleaseRowPresentation presentation) {
            if (presentation.progress_indeterminate &&
                progress_pulse_timeout_id == 0) {
                progress_bar.reset_property (Gtk.AccessibleProperty.VALUE_NOW);
                progress_bar.pulse (0.01);
                progress_pulse_timeout_id = start_progress_pulse_timeout (this);
            } else if (!presentation.progress_indeterminate) {
                stop_progress_pulse ();
            }
        }

        static uint start_progress_pulse_timeout (ReleaseRow owner) {
            var owner_ref = WeakRef (owner);
            return Timeout.add (16, () => {
                    var row = owner_ref.get () as ReleaseRow;
                    if (row == null || ((!) row).row_disposed)
                        return Source.REMOVE;
                    ((!) row).progress_bar.pulse (0.01);
                    return Source.CONTINUE;
                });
        }

        void stop_progress_pulse () {
            if (progress_pulse_timeout_id == 0)
                return;
            Source.remove (progress_pulse_timeout_id);
            progress_pulse_timeout_id = 0;
        }

        public void release_row_job_progress_changed () {
            if (row_disposed)
                return;

            if (job.is_percent && job.progress != null) {
                var percentage = double.parse (job.progress.replace ("%", ""));
                progress_bar.fraction = percentage / 100.0;
                progress_bar.update_property (
                    Gtk.AccessibleProperty.VALUE_NOW, percentage,
                    Gtk.AccessibleProperty.VALUE_TEXT, job.progress,
                    -1
                );
            } else if (current_presentation ().progress_indeterminate) {
                progress_bar.reset_property (Gtk.AccessibleProperty.VALUE_NOW);
                progress_bar.update_property (
                    Gtk.AccessibleProperty.VALUE_TEXT,
                    operation_step_text (),
                    -1
                );
            }

            speed_label.set_label (_("Speed: %s/s").printf (
                Utils.Filesystem.convert_download_speed_to_string (
                    (int64) (job.speed_kbps * 1024)
                )
            ));
            time_label.set_label (job.seconds_remaining >= 0
                ? _("Remaining time: %s").printf (
                    format_time (job.seconds_remaining)
                )
                : _("Remaining time: --"));
        }

        string format_time (double seconds) {
            int total = (int) seconds;
            int hours = total / 3600;
            int minutes = (total % 3600) / 60;
            int remaining_seconds = total % 60;
            if (hours > 0)
                return _("%dh %dm %ds").printf (
                    hours, minutes, remaining_seconds
                );
            if (minutes > 0)
                return _("%dm %ds").printf (minutes, remaining_seconds);
            return _("%ds").printf (remaining_seconds);
        }

        void primary_button_clicked () {
            if (action_request_in_progress || row_disposed)
                return;
            job.refresh_state ();
            switch (current_presentation ().primary_action) {
            case ReleaseRowPrimaryAction.INSTALL:
                install_button_clicked ();
                break;
            case ReleaseRowPrimaryAction.RETRY:
                if (retry_action == ReleaseRowRetryAction.INSTALL)
                    install_button_clicked ();
                break;
            default:
                break;
            }
        }

        void request_update () {
            if (action_request_in_progress || row_disposed)
                return;
            job.refresh_state ();
            if (current_presentation ().show_update_action)
                begin_update ();
        }

        void begin_update () {
            retry_action = ReleaseRowRetryAction.NONE;
            operation_error_message = null;
            update_action_request_state (true);
            run_update (job, this);
        }

        static void run_update (
            Services.InstallJob operation_job,
            ReleaseRow owner
        ) {
            var owner_ref = WeakRef (owner);
            operation_job.update.begin ((obj, res) => {
                var code = operation_job.update.end (res);
                if (code == ReturnCode.RUNNER_UPDATED)
                    Utils.DownloadManager.instance.tool_updated (
                        operation_job, true
                    );
                else if (code == ReturnCode.NOTHING_TO_UPDATE)
                    Utils.DownloadManager.instance.tool_updated (
                        operation_job, false
                    );

                var row = owner_ref.get () as ReleaseRow;
                if (row == null || ((!) row).row_disposed)
                    return;
                ((!) row).retry_action = code != ReturnCode.RUNNER_UPDATED &&
                    code != ReturnCode.NOTHING_TO_UPDATE &&
                    !operation_job.canceled
                    ? ReleaseRowRetryAction.UPDATE
                    : ReleaseRowRetryAction.NONE;
                ((!) row).operation_error_message = ((!) row).retry_action != ReleaseRowRetryAction.NONE
                    ? get_return_code_message (code)
                    : null;
                ((!) row).update_action_request_state (false);
                if (code != ReturnCode.RUNNER_UPDATED &&
                    code != ReturnCode.NOTHING_TO_UPDATE &&
                    !operation_job.canceled) {
                    warning (
                        "Failed to update %s: %s",
                        operation_job.title,
                        operation_job.error_message ?? get_return_code_message (code)
                    );
                }
            });
        }

        void open_folder () {
            if (action_request_in_progress || row_disposed)
                return;
            job.refresh_state ();
            if (current_presentation ().show_open_folder)
                Utils.System.open_path (job.install_location);
        }

        protected virtual void install_button_clicked () {
            if (action_request_in_progress || row_disposed)
                return;
            retry_action = ReleaseRowRetryAction.NONE;
            operation_error_message = null;
            update_action_request_state (true);
            run_install (job, this);
        }

        static void run_install (
            Services.InstallJob operation_job,
            ReleaseRow owner
        ) {
            var owner_ref = WeakRef (owner);
            operation_job.install.begin ((obj, res) => {
                var code = operation_job.install.end (res);
                var row = owner_ref.get () as ReleaseRow;
                if (row == null || ((!) row).row_disposed)
                    return;
                ((!) row).retry_action = code != ReturnCode.RUNNER_INSTALLED &&
                    !operation_job.canceled
                    ? ReleaseRowRetryAction.INSTALL
                    : ReleaseRowRetryAction.NONE;
                ((!) row).operation_error_message = ((!) row).retry_action != ReleaseRowRetryAction.NONE
                    ? get_return_code_message (code)
                    : null;
                ((!) row).update_action_request_state (false);
                if (code != ReturnCode.RUNNER_INSTALLED &&
                    !operation_job.canceled) {
                    warning (
                        "Failed to install %s: %s",
                        operation_job.title,
                        operation_job.error_message ?? get_return_code_message (code)
                    );
                }
            });
        }

        void request_removal () {
            if (action_request_in_progress || row_disposed)
                return;
            job.refresh_state ();
            if (!current_presentation ().show_delete)
                return;

            update_action_request_state (true);
            var dialog = new RemoveDialog (job);
            customize_remove_dialog (dialog);
            track_removal_dialog (dialog, this);
            var root = get_root () as Gtk.Window;
            if (root != null)
                ProtonPlus.Widgets.Window.present_dialog_for_controller (
                    dialog, (!) root
                );
            else
                update_action_request_state (false);
        }

        static void track_removal_dialog (RemoveDialog dialog, ReleaseRow owner) {
            var owner_ref = WeakRef (owner);
            dialog.closed.connect (() => {
                var row = owner_ref.get () as ReleaseRow;
                if (row != null && !((!) row).row_disposed)
                    ((!) row).update_action_request_state (false);
            });
        }

        protected virtual void customize_remove_dialog (RemoveDialog dialog) {}

        protected void update_action_request_state (bool in_progress) {
            action_request_in_progress = in_progress;
            if (!row_disposed)
                refresh_presentation ();
        }

        public void refresh_usage_pill () {
            if (!row_disposed)
                refresh_status_text ();
        }

        bool is_busy_state (Services.InstallJob.State state) {
            return state == Services.InstallJob.State.BUSY_INSTALLING ||
                state == Services.InstallJob.State.BUSY_UPDATING ||
                state == Services.InstallJob.State.BUSY_REMOVING;
        }

    }
}
