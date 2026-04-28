namespace ProtonPlus.Widgets.Main {
    public class Box : Gtk.Box {
        public Adw.ViewStack view_stack { get; set; }
        public Adw.ViewSwitcher view_switcher { get; set; }
        Adw.ToastOverlay toast_overlay { get; set; }

        string previous_view_name { get; set; }

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
            view_stack.add_titled_with_icon (mangohud_box, "mangohud", _ ("MangoHud"), "layer-group-symbolic");

            view_switcher = new Adw.ViewSwitcher ();
            view_switcher.set_stack (view_stack);
            view_switcher.set_policy (Adw.ViewSwitcherPolicy.WIDE);

            toast_overlay = new Adw.ToastOverlay ();
            toast_overlay.set_child (view_stack);

            append (toast_overlay);

            Utils.DownloadManager.instance.download_added.connect (on_download_added);
            Utils.DownloadManager.instance.download_finished.connect (on_download_finished);
            Utils.DownloadManager.instance.tool_updated.connect (on_tool_updated);
            Utils.DownloadManager.instance.tool_removed.connect (on_tool_removed);
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            tools_box.set_selected_launcher (launcher);
            games_box.set_selected_launcher (launcher);
        }

        public void send_toast (string title) {
            var toast = new Adw.Toast (title);

            toast_overlay.add_toast (toast);
        }

        void on_download_added (Models.Release release) {
            if (release.state == Models.Release.State.BUSY_UPDATING) {
                send_notification (_ ("Update started"), release.displayed_title);
            } else {
                send_notification (_ ("Download started"), release.displayed_title);
            }
        }

        void on_download_finished (Models.Release release, bool success) {
            if (success) {
                send_notification (_ ("Download finished"), release.displayed_title);
            } else if (release.canceled) {
                send_notification (_ ("Download canceled"), release.displayed_title);
            } else {
                var body = release.displayed_title;
                if (release.error_message != null && release.error_message != "") {
                    body = "%s (%s)".printf (release.displayed_title, release.error_message);
                }
                send_notification (_ ("Download failed"), body);
            }
        }

        void on_tool_updated (Models.Release release, bool updated) {
            if (updated) {
                send_notification (_ ("Update finished"), _ ("%s is now up-to-date").printf (release.displayed_title));
            } else {
                send_notification (_ ("Update finished"), _ ("%s is already up-to-date").printf (release.displayed_title));
            }
        }

        void on_tool_removed (Models.Release release) {
            send_notification (_ ("Deleted"), release.displayed_title, "user-trash-symbolic");
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
            if (previous_view_name == "games")
            games_box.show_games_list_page ();

            switch (previous_view_name) {
                case "games":
                    games_box.show_games_list_page ();
                    break;
                case "mangohud":
                    mangohud_box.show_presets_page ();
                    break;
            }

            previous_view_name = view_stack.get_visible_child_name ();
        }

        //        public async void check_for_updates (Models.Tools.Basic? runner = null) {
        //            Adw.Toast toast;
        //            ReturnCode code;
        //
        //            var runner_title = runner != null ? runner.title : "";
        //            var is_specific_update = runner != null;
        //
        //            toast = new Adw.Toast (
        //                    is_specific_update ?
        //                    _ ("Updating %s").printf ("%s Latest".printf (runner_title)) :
        //                    _ ("Checking for updates")
        //            );
        //
        //            toast_overlay.add_toast (toast);
        //
        //            code = (
        //            is_specific_update ?
        //            yield Models.Tool.update_specific_runner (runner as Models.Tools.Basic) :
        //            yield Models.Tool.check_for_updates (launchers)
        //            );
        //
        //            toast.dismiss ();
        //
        //            switch (code) {
        //                case ReturnCode.NOTHING_TO_UPDATE:
        //                    toast = new Adw.Toast (
        //                            is_specific_update ?
        //                            _ ("No update found for %s").printf ("%s Latest".printf (runner_title)) :
        //                            _ ("Nothing to update"));
        //                    break;
        //                case ReturnCode.RUNNERS_UPDATED:
        //                case ReturnCode.RUNNER_UPDATED:
        //                    toast = new Adw.Toast (
        //                            is_specific_update ?
        //                            _ ("%s is now up-to-date").printf ("%s Latest".printf (runner_title)) :
        //                            _ ("Everything is now up-to-date"));
        //                    break;
        //                case ReturnCode.API_LIMIT_REACHED:
        //                    toast = new Adw.Toast (
        //                            is_specific_update ?
        //                            _ ("Couldn't update %s (Reason: %s)").printf (runner_title, _ ("API limit reached")) :
        //                            _ ("Couldn't check for updates (Reason: %s)").printf (_ ("API limit reached")));
        //                    break;
        //                case ReturnCode.CONNECTION_ISSUE:
        //                case ReturnCode.CONNECTION_REFUSED:
        //                case ReturnCode.CONNECTION_UNKNOWN:
        //                    toast = new Adw.Toast (
        //                            is_specific_update ?
        //                            _ ("Couldn't update %s (Reason: %s)").printf (runner_title, _ ("Unable to reach the API")) :
        //                            _ ("Couldn't check for updates (Reason: %s)").printf (_ ("Unable to reach the API")));
        //                    break;
        //                case ReturnCode.INVALID_ACCESS_TOKEN:
        //                    toast = new Adw.Toast (
        //                            is_specific_update ?
        //                            _ ("Couldn't update %s (Reason: %s)").printf (runner_title, _ ("Invalid access token")) :
        //                            _ ("Couldn't check for updates (Reason: %s)").printf (_ ("Invalid access token")));
        //                    break;
        //                default:
        //                    toast = new Adw.Toast (
        //                            is_specific_update ?
        //                            _ ("Couldn't update %s (Reason: %s)").printf (runner_title, _ ("Unknown error")) :
        //                            _ ("Couldn't check for updates (Reason: %s)").printf (_ ("Unknown error")));
        //                    toast.set_button_label (_ ("Report"));
        //                    toast.set_action_name ("app.report");
        //                    break;
        //            }
        //
        //            toast_overlay.add_toast (toast);
        //        }
    }
}
