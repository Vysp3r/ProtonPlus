namespace ProtonPlus.Widgets.Main {
    public class Box : Gtk.Box, Utils.ControllerNavigationHost,
        Utils.ControllerPageShortcuts {
        public Adw.ViewStack view_stack { get; set; }
        public Adw.ViewSwitcher view_switcher { get; set; }
        Adw.ToastOverlay toast_overlay { get; set; }

        string previous_view_name { get; set; }
        string? view_switcher_pressed_page { get; set; }

        Tools.Box tools_box { get; set; }
        Games.Box games_box { get; set; }
        MangoHud.Box mangohud_box { get; set; }
        private Services.SteamRestartManager? restart_manager;
        private Services.SteamRestartOrchestrator? restart_orchestrator;
        private SteamRestartBanner? restart_banner;
        private SteamRestartToastPolicy? restart_toasts;
        private SteamRestartNotificationCoordinator? restart_notifications;
        private uint previous_restart_count = 0;
        private ulong pending_changed_handler_id = 0;
        private ulong persistence_failed_handler_id = 0;
        private ulong state_changed_handler_id = 0;
        private ulong operation_completed_handler_id = 0;
        private Cancellable? restart_cancellable = null;
        private Adw.Dialog? active_restart_dialog = null;
        private bool persistence_toast_shown = false;
        private bool load_warning_shown = false;

        public Box (Services.SteamRestartManager? restart_manager = null,
            Services.SteamRestartOrchestrator? restart_orchestrator = null,
            SteamRestartNotificationSender? restart_notification_sender = null) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.restart_manager = restart_manager;
            this.restart_orchestrator = restart_orchestrator;

            tools_box = new Tools.Box ();
            tools_box.toast_sent.connect (send_toast);

            games_box = new Games.Box ();

            mangohud_box = new MangoHud.Box ();

            view_stack = new Adw.ViewStack ();
            view_stack.notify["visible-child-name"].connect (view_stack_visible_child_name_changed);
            view_stack.add_titled_with_icon (tools_box, "tools", _ ("Tools"), "toolbox-symbolic");
            view_stack.add_titled_with_icon (games_box, "games", _ ("Games"), "gamepad-symbolic");

            var mangohud_page = view_stack.add_titled_with_icon (mangohud_box, "mangohud", _ ("MangoHud"), "layer-group-symbolic");

            if (Globals.MANGOHUD_INSTALLED || Globals.MANGOHUD_FLATPAK_INSTALLED) {
                Globals.SETTINGS.bind ("experimental-features", mangohud_page, "visible", SettingsBindFlags.DEFAULT);
            } else {
                mangohud_page.visible = false;
            }

            view_switcher = new Adw.ViewSwitcher ();
            view_switcher.set_stack (view_stack);
            view_switcher.set_policy (Adw.ViewSwitcherPolicy.WIDE);

            var reset_controller = new Gtk.GestureClick ();
            reset_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            reset_controller.pressed.connect ((gesture, n_press, x, y) => {
                if (n_press == 1)
                    view_switcher_pressed_page = view_stack.get_visible_child_name ();
            });
            reset_controller.released.connect ((gesture, n_press, x, y) => {
                if (n_press != 1)
                    return;

                var pressed_page = view_switcher_pressed_page;
                view_switcher_pressed_page = null;

                Idle.add (() => {
                    if (pressed_page != null && pressed_page == view_stack.get_visible_child_name ())
                        reset_visible_page ();
                    return Source.REMOVE;
                });
            });
            view_switcher.add_controller (reset_controller);

            toast_overlay = new Adw.ToastOverlay ();
            toast_overlay.set_child (view_stack);

            if (restart_manager != null && restart_orchestrator != null)
                setup_steam_restart_presentation ((!) restart_manager, (!) restart_orchestrator,
                    restart_notification_sender ?? new LibnotifySteamRestartNotificationSender ());
            append (toast_overlay);

            Utils.DownloadManager.instance.download_added.connect (on_download_added);
            Utils.DownloadManager.instance.download_finished.connect (on_download_finished);
            Utils.DownloadManager.instance.tool_updated.connect (on_tool_updated);
            Utils.DownloadManager.instance.tool_removed.connect (on_tool_removed);
        }

        public void initialize (Gee.LinkedList<Models.Launcher> launchers) {
            foreach (var launcher in launchers) {
                if (launcher is Models.Launchers.Steam) {
                    var steam_launcher = launcher as Models.Launchers.Steam;
                    steam_launcher.notify["profile"].connect (games_box.load_games);
                    break;
                }
            }
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            tools_box.set_selected_launcher (launcher);
            games_box.set_selected_launcher (launcher);
        }

        public void navigate_to_download (Services.InstallJob job) {
            view_stack.set_visible_child_name ("tools");
            tools_box.show_download (job);
        }

        public void send_toast (string title) {
            var toast = new Adw.Toast (title);

            toast_overlay.add_toast (toast);
        }

        public void cancel_steam_restart () {
            if (restart_cancellable != null)
                restart_cancellable.cancel ();
        }

        private void setup_steam_restart_presentation (Services.SteamRestartManager manager,
            Services.SteamRestartOrchestrator orchestrator, SteamRestartNotificationSender notification_sender) {
            restart_banner = new SteamRestartBanner ();
            restart_banner.restart_requested.connect (show_restart_review);
            append (restart_banner);
            restart_toasts = new SteamRestartToastPolicy ();
            restart_notifications = new SteamRestartNotificationCoordinator (notification_sender);
            previous_restart_count = (uint) manager.pending_count ();
            update_restart_banner ();
            pending_changed_handler_id = manager.pending_changed.connect (() => {
                var current = (uint) manager.pending_count ();
                var window = get_root () as Gtk.Window;
                var active = window != null && window.is_active;
                var toast = restart_toasts.update (previous_restart_count, current, false);
                restart_notifications.update (previous_restart_count, current, active, false);
                previous_restart_count = current;
                if (current == 0)
                    persistence_toast_shown = false;
                update_restart_banner ();
                if (active && toast != null)
                    send_toast ((!) toast);
            });
            persistence_failed_handler_id = manager.persistence_failed.connect ((message) => {
                warning ("Unable to save Steam restart reminder: %s", message);
                if (!persistence_toast_shown) {
                    persistence_toast_shown = true;
                    send_toast (_ ("Couldn’t save the Steam restart reminder"));
                }
            });
            state_changed_handler_id = orchestrator.state_changed.connect ((state) => {
                if (orchestrator.is_operation_active)
                    restart_banner.show_progress (state);
            });
            operation_completed_handler_id = orchestrator.operation_completed.connect (on_restart_completed);
            if (manager.last_load_error != null) {
                Idle.add (() => {
                    if (!load_warning_shown && get_root () != null) {
                        load_warning_shown = true;
                        send_toast (_ ("Saved Steam restart reminders couldn’t be loaded"));
                    }
                    return Source.REMOVE;
                });
            }
        }

        private void update_restart_banner () {
            if (restart_manager == null || restart_banner == null || restart_orchestrator == null)
                return;
            if (restart_orchestrator.is_operation_active) {
                restart_banner.show_progress (restart_orchestrator.state);
                return;
            }
            restart_banner.show_pending (SteamRestartPresentation.banner_state (restart_manager.get_pending_changes ()));
        }

        private void show_restart_review () {
            if (restart_manager == null || restart_orchestrator == null || restart_orchestrator.is_operation_active)
                return;
            if (active_restart_dialog != null) {
                Window.present_dialog_for_controller ((!) active_restart_dialog, this);
                return;
            }
            var summaries = SteamRestartPresentation.summarize (restart_manager.get_pending_changes ());
            if (summaries.size == 0)
                return;
            if (summaries.size > 1) {
                var review = new SteamRestartReviewDialog (summaries);
                active_restart_dialog = review;
                review.restart_requested.connect ((target) => { start_steam_restart (target); });
                review.closed.connect (() => { if (active_restart_dialog == review) active_restart_dialog = null; });
                Window.present_dialog_for_controller (review, this);
                return;
            }
            var summary = summaries[0];
            var body = ngettext ("Steam needs to restart before this change takes effect.", "Steam needs to restart before these %u changes take effect.", summary.pending_count).printf (summary.pending_count);
            body += "\n\n" + _ ("Save your progress and close any running games before continuing. In SteamOS Gaming Mode, Steam, running games, and ProtonPlus will close while Steam restarts.");
            var dialog = new Adw.AlertDialog (_ ("Restart Steam?"), body);
            dialog.add_response ("later", _ ("Later"));
            dialog.add_response ("restart", _ ("Restart Steam"));
            dialog.set_default_response ("later");
            dialog.set_close_response ("later");
            dialog.set_response_appearance ("restart", Adw.ResponseAppearance.SUGGESTED);
            active_restart_dialog = dialog;
            dialog.response.connect ((response) => { if (response == "restart") start_steam_restart (summary.target); });
            dialog.closed.connect (() => { if (active_restart_dialog == dialog) active_restart_dialog = null; });
            Window.present_dialog_for_controller (dialog, this);
        }

        private void start_steam_restart (Models.SteamRestartTarget target) {
            if (restart_orchestrator == null || restart_orchestrator.is_operation_active)
                return;
            if (active_restart_dialog != null)
                active_restart_dialog.close ();
            restart_cancellable = new Cancellable ();
            restart_orchestrator.restart_target.begin (target, restart_cancellable, (obj, response) => {
                restart_orchestrator.restart_target.end (response);
            });
        }

        private void on_restart_completed (Models.SteamRestartOperationResult result) {
            restart_cancellable = null;
            update_restart_banner ();
            if (result.final_state == Models.SteamRestartOperationState.STEAMOS_HANDOFF_REQUESTED) {
                var handoff = SteamRestartPresentation.steamos_handoff_message ();
                if (handoff.toast != null)
                    send_toast ((!) handoff.toast);
                return;
            }
            if (result.final_state == Models.SteamRestartOperationState.SUCCEEDED) {
                var message = SteamRestartPresentation.success_message (restart_manager != null && restart_manager.get_pending_targets ().size > 0, result.persistence_failed);
                if (message.toast != null)
                    send_toast ((!) message.toast);
                else if (message.heading != null)
                    show_restart_message (message, result.target);
                return;
            }
            var failure = SteamRestartPresentation.failure_message (result.reason, result.steam_confirmed_stopped);
            if (failure.toast != null) {
                if (result.reason != Models.SteamRestartFailureReason.CANCELLED || result.shutdown_request_sent || result.launch_request_sent)
                    send_toast ((!) failure.toast);
                return;
            }
            if (failure.heading != null)
                show_restart_message (failure, result.target);
        }

        private void show_restart_message (SteamRestartMessage message, Models.SteamRestartTarget target) {
            var dialog = new Adw.AlertDialog (message.heading, message.body);
            dialog.add_response ("later", _ ("Later"));
            dialog.set_close_response ("later");
            dialog.set_default_response ("later");
            if (message.can_retry) {
                dialog.add_response ("retry", _ ("Try Again"));
                dialog.set_response_appearance ("retry", Adw.ResponseAppearance.SUGGESTED);
                dialog.response.connect ((response) => { if (response == "retry") start_steam_restart (target); });
            }
            active_restart_dialog = dialog;
            dialog.closed.connect (() => { if (active_restart_dialog == dialog) active_restart_dialog = null; });
            Window.present_dialog_for_controller (dialog, this);
        }

        public override void dispose () {
            cancel_steam_restart ();
            if (active_restart_dialog != null)
                active_restart_dialog.close ();
            active_restart_dialog = null;
            if (restart_manager != null) {
                if (pending_changed_handler_id != 0) restart_manager.disconnect (pending_changed_handler_id);
                if (persistence_failed_handler_id != 0) restart_manager.disconnect (persistence_failed_handler_id);
            }
            if (restart_orchestrator != null) {
                if (state_changed_handler_id != 0) restart_orchestrator.disconnect (state_changed_handler_id);
                if (operation_completed_handler_id != 0) restart_orchestrator.disconnect (operation_completed_handler_id);
            }
            base.dispose ();
        }

        public async void check_for_updates (Gee.LinkedList<Models.Launcher> launchers) {
            send_toast (_ ("Checking for updates"));

            var list = new List<Models.Launcher> ();
            foreach (var launcher in launchers) {
                list.append (launcher);
            }

            var code = yield Services.InstallationService.instance.check_for_updates (list);

            switch (code) {
                case ReturnCode.RUNNERS_IN_USE:
                    send_toast (_ ("Can't update while a game is running"));
                    break;
                case ReturnCode.NOTHING_TO_UPDATE:
                    send_toast (_ ("Nothing to update"));
                    break;
                case ReturnCode.RUNNERS_UPDATED:
                case ReturnCode.RUNNER_UPDATED:
                    send_toast (_ ("Everything is now up-to-date"));
                    break;
                default:
                    send_toast (_ ("Couldn't check for updates (Reason: %s)").printf (get_return_code_message (code)));
                    break;
            }
        }

        void on_download_added (Services.InstallJob job) {
            if (job.state == Services.InstallJob.State.BUSY_UPDATING) {
                send_notification (_ ("Update started"), job.displayed_title);
            } else {
                send_notification (_ ("Download started"), job.displayed_title);
            }
        }

        void on_download_finished (Services.InstallJob job, bool success) {
            if (success) {
                send_notification (_ ("Download finished"), job.displayed_title);
            } else if (job.canceled) {
                send_notification (_ ("Download canceled"), job.displayed_title);
            } else {
                var body = job.displayed_title;
                if (job.error_message != null && job.error_message != "") {
                    body = "%s (%s)".printf (job.displayed_title, job.error_message);
                }
                send_notification (_ ("Download failed"), body);
            }
        }

        void on_tool_updated (Services.InstallJob job, bool updated) {
            if (updated) {
                send_notification (_ ("Update finished"), _ ("%s is now up-to-date").printf (job.displayed_title));
            } else {
                send_notification (_ ("Update finished"), _ ("%s is already up-to-date").printf (job.displayed_title));
            }
        }

        void on_tool_removed (Services.InstallJob job) {
            send_notification (_ ("Deleted"), job.displayed_title, "user-trash-symbolic");
        }

        void send_notification (string title, string body, string icon = "folder-download-symbolic") {
            var window = get_root () as Gtk.Window;

            send_toast ("%s: %s".printf (title, body));

            if (window == null || !window.is_active) {
                var notification = new Notify.Notification (title, body, icon);
                try {
                    notification.show ();
                } catch (Error e) {
                    warning ("Failed to send notification: %s", e.message);
                }
            }
        }

        void view_stack_visible_child_name_changed () {
            switch (previous_view_name) {
                case "tools":
                    tools_box.show_groups_page ();
                    break;
                case "games":
                    games_box.show_games_list_page ();
                    break;
                case "mangohud":
                    mangohud_box.show_presets_page ();
                    break;
            }

            previous_view_name = view_stack.get_visible_child_name ();
        }

        void reset_visible_page () {
            switch (view_stack.get_visible_child_name ()) {
                case "tools":
                    tools_box.show_groups_page ();
                    break;
                case "games":
                    games_box.show_games_list_page ();
                    break;
                case "mangohud":
                    mangohud_box.show_presets_page ();
                    break;
            }
        }

        Utils.ControllerNavigationHost? get_visible_controller_host () {
            return view_stack.get_visible_child () as Utils.ControllerNavigationHost;
        }

        public string get_controller_page_id () {
            var host = get_visible_controller_host ();
            if (host != null)
                return host.get_controller_page_id ();
            return "main:%s".printf (view_stack.get_visible_child_name () ?? "unknown");
        }

        public Object? get_controller_page_root () {
            var host = get_visible_controller_host ();
            if (host != null)
                return host.get_controller_page_root ();
            return view_stack.get_visible_child ();
        }

        public Object? get_controller_initial_focus () {
            var host = get_visible_controller_host ();
            return host?.get_controller_initial_focus ();
        }

        public bool controller_navigate_back () {
            var host = get_visible_controller_host ();
            return host != null && host.controller_navigate_back ();
        }

        public bool controller_can_navigate_back () {
            var host = get_visible_controller_host ();
            return host != null && host.controller_can_navigate_back ();
        }

        public bool controller_can_switch_page () {
            var model = view_stack.pages;
            int visible_count = 0;
            for (uint i = 0; i < model.get_n_items (); i++) {
                var page = (Adw.ViewStackPage) model.get_item (i);
                if (page.visible)
                    visible_count++;
            }
            return visible_count >= 2;
        }

        public bool controller_prefers_initial_focus_after_switch () {
            var page = view_stack.get_visible_child_name ();
            return page == "games" || page == "tools";
        }

        public bool controller_switch_page (int delta) {
            var model = view_stack.pages;
            int count = (int) model.get_n_items ();
            if (count < 2)
                return false;

            string? current = view_stack.visible_child_name;
            int current_index = 0;
            for (int i = 0; i < count; i++) {
                var page = (Adw.ViewStackPage) model.get_item ((uint) i);
                if (page.name == current) {
                    current_index = i;
                    break;
                }
            }

            for (int step = 1; step <= count; step++) {
                int index = ((current_index + delta * step) % count + count) % count;
                var page = (Adw.ViewStackPage) model.get_item ((uint) index);
                if (page.visible && page.name != current) {
                    view_stack.visible_child_name = page.name;
                    return true;
                }
            }
            return false;
        }

        Utils.ControllerPageShortcuts? get_visible_controller_shortcuts () {
            return view_stack.get_visible_child () as Utils.ControllerPageShortcuts;
        }

        public bool controller_can_open_search () {
            var shortcuts = get_visible_controller_shortcuts ();
            return shortcuts != null && shortcuts.controller_can_open_search ();
        }

        public bool controller_can_open_filter () {
            var shortcuts = get_visible_controller_shortcuts ();
            return shortcuts != null && shortcuts.controller_can_open_filter ();
        }

        public bool controller_open_search () {
            var shortcuts = get_visible_controller_shortcuts ();
            return shortcuts != null && shortcuts.controller_open_search ();
        }

        public bool controller_open_filter () {
            var shortcuts = get_visible_controller_shortcuts ();
            return shortcuts != null && shortcuts.controller_open_filter ();
        }
    }
}
