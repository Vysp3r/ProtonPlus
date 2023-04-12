namespace Windows {
    public class Main : Adw.ApplicationWindow {
        public States State;
        public GLib.List<Task> Tasks;
        public delegate void TaskCallback ();

        public class Task {
            public TaskCallback Callback;

            public Task (owned TaskCallback callback) {
                Callback = (owned) callback;
            }
        }

        public enum States {
            NORMAL,
            INSTALLING_TOOL,
            CLOSING
        }

        Gtk.Notebook notebook;
        Adw.ToastOverlay toastOverlay;

        public Main (Adw.Application app) {
            //
            State = States.NORMAL;

            //
            ActionEntry[] action_entries = {
                { "preferences", on_preferences_action },
                { "telegram", () => Gtk.show_uri (null, "https://t.me/ProtonPlus", Gdk.CURRENT_TIME) },
                { "documentation", () => Gtk.show_uri (null, "https://github.com/Vysp3r/ProtonPlus/wiki", Gdk.CURRENT_TIME) },
                { "donation", () => Gtk.show_uri (null, "https://www.youtube.com/watch?v=dQw4w9WgXcQ", Gdk.CURRENT_TIME) },
                { "about", on_about_action },
                { "quit", app.quit }
            };
            app.add_action_entries (action_entries, this);

            //
            set_application (app);
            set_title ("ProtonPlus");
            set_size_request (900, 600);

            //
            toastOverlay = new Adw.ToastOverlay ();

            //
            notebook = new Gtk.Notebook ();
            notebook.set_show_tabs (false);

            //
            var leaflet = new Adw.Leaflet ();
            leaflet.set_transition_type (Adw.LeafletTransitionType.OVER);
            leaflet.set_can_unfold (false);
            leaflet.set_fold_threshold_policy (Adw.FoldThresholdPolicy.NATURAL);
            leaflet.prepend (new Windows.ViewManager (leaflet, toastOverlay, notebook));
            leaflet.get_pages ().select_item (0, true);

            //
            notebook.append_page (leaflet);
            notebook.append_page (new Windows.Preferences.Main (notebook, toastOverlay));
            notebook.append_page (new Windows.Errors.GithubApiRequest (notebook));

            //
            toastOverlay.set_child (notebook);

            //
            set_content (toastOverlay);
        }

        void on_about_action () {
            string[] devs = { "Charles Malouin (Vysp3r) https:// github.com/Vysp3r", "windblows95 https://github.com/windblows95" };
            string[] designers = { "Charles Malouin (Vysp3r) https://github.com/Vysp3r" };
            string[] thanks = {
                "GNOME Project https://www.gnome.org/",
                "ProtonUp-Qt Project https://davidotek.github.io/protonup-qt/",
                "LUG Helper Project https://github.com/starcitizen-lug/lug-helper"
            };

            var aboutDialog = new Adw.AboutWindow ();

            aboutDialog.set_application_name ("ProtonPlus");
            aboutDialog.set_application_icon ("com.vysp3r.ProtonPlus");
            aboutDialog.set_version ("v" + Utils.Constants.APP_VERSION);
            aboutDialog.set_comments (_ ("A simple Wine and Proton-based compatiblity tools manager for GNOME"));
            aboutDialog.add_link ("Github", "https://github.com/Vysp3r/ProtonPlus");
            aboutDialog.set_issue_url ("https://github.com/Vysp3r/ProtonPlus/issues/new/choose");
            aboutDialog.set_copyright ("© 2022 Vysp3r");
            aboutDialog.set_license_type (Gtk.License.GPL_3_0);
            aboutDialog.set_developers (devs);
            aboutDialog.set_designers (designers);
            aboutDialog.add_credit_section (_ ("Special thanks to"), thanks);
            aboutDialog.set_transient_for (this);
            aboutDialog.set_modal (true);

            aboutDialog.show ();
        }

        void on_preferences_action () {
            notebook.set_current_page (1);
        }

        public override bool close_request () {
            bool busy = false;

            if (State == States.INSTALLING_TOOL) {
                var toast = new Adw.Toast (_ ("You cannot close the window while a tool is installing"));
                toastOverlay.add_toast (toast);
                busy = true;
            }

            if (!busy) {
                State = States.CLOSING;
                set_visible (false);
                foreach (var task in Tasks) task.Callback ();
            }

            return busy;
        }
    }
}
