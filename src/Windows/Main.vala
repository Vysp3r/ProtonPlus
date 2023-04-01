namespace Windows {
    public class Main : Adw.ApplicationWindow {
        Gtk.Notebook notebook;

        public Main (Adw.Application app) {
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
            set_size_request (800, 500);

            //
            var toastOverlay = new Adw.ToastOverlay ();

            //
            var leaflet = new Adw.Leaflet ();
            leaflet.set_transition_type (Adw.LeafletTransitionType.OVER);
            leaflet.set_can_unfold (false);
            leaflet.set_fold_threshold_policy (Adw.FoldThresholdPolicy.NATURAL);
            leaflet.prepend (new Windows.ViewManager (leaflet, toastOverlay));
            leaflet.get_pages ().select_item (0, true);

            //
            notebook = new Gtk.Notebook ();
            notebook.set_show_tabs (false);
            notebook.append_page (leaflet);
            notebook.append_page (new Windows.Preferences (notebook));

            //
            toastOverlay.set_child (notebook);

            //
            set_content (toastOverlay);
        }

        void on_about_action () {
            string[] devs = { "Charles Malouin (Vysp3r) https:// github.com/Vysp3r" };
            string[] designers = { "Charles Malouin (Vysp3r) https://github.com/Vysp3r" };
            string[] thanks = {
                "GNOME Project https://www.gnome.org/",
                "ProtonUp-Qt Project https://davidotek.github.io/protonup-qt/",
                "LUG Helper Project https://github.com/starcitizen-lug/lug-helper",
                "Lahey"
            };

            var aboutDialog = new Adw.AboutWindow ();

            aboutDialog.set_application_name ("ProtonPlus");
            aboutDialog.set_application_icon ("com.vysp3r.ProtonPlus");
            aboutDialog.set_version ("v" + Utils.Constants.APP_VERSION);
            aboutDialog.set_comments ("A simple Wine and Proton-based compatiblity tools manager for GNOME");
            aboutDialog.add_link ("Github", "https://github.com/Vysp3r/ProtonPlus");
            aboutDialog.set_issue_url ("https://github.com/Vysp3r/ProtonPlus/issues/new/choose");
            aboutDialog.set_copyright ("© 2022 Vysp3r");
            aboutDialog.set_license_type (Gtk.License.GPL_3_0);
            aboutDialog.set_developers (devs);
            aboutDialog.set_designers (designers);
            aboutDialog.add_credit_section ("Special thanks to", thanks);
            aboutDialog.set_transient_for (this);
            aboutDialog.set_modal (true);

            aboutDialog.show ();
        }

        void on_preferences_action () {
            notebook.set_current_page (1);
        }
    }
}
