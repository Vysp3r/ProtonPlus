namespace ProtonPlus.Widgets.Main {
    public class Box : Gtk.Box {
        public Adw.ViewStack view_stack { get; set; }
        public Adw.ViewSwitcher view_switcher { get; set; }
        Adw.ToastOverlay toast_overlay { get; set; }

        string previous_view_name { get; set; }
        string? view_switcher_pressed_page { get; set; }

        Tools.Box tools_box { get; set; }
        Games.Box games_box { get; set; }
        MangoHud.Box mangohud_box { get; set; }

        public Box () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

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
    }
}
