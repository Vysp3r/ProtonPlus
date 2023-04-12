namespace Windows {
    public class ViewManager : Gtk.Box {
        public ViewManager (Adw.Leaflet leaflet, Adw.ToastOverlay toastOverlay, Gtk.Notebook notebook) {
            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            //
            var headerBar = new Adw.HeaderBar ();
            headerBar.set_centering_policy (Adw.CenteringPolicy.STRICT);
            append (headerBar);

            //
            if (GLib.Environment.get_variable ("DESKTOP_SESSION") != "gamescope-wayland") {
                //
                var menu = new Gtk.MenuButton ();
                menu.set_icon_name ("open-menu-symbolic");

                //
                var menu_model_about = new Menu ();
                menu_model_about.append (_ ("Telegram"), "app.telegram");
                menu_model_about.append (_ ("Documentation"), "app.documentation");
                menu_model_about.append (_ ("Donation"), "app.donation");
                menu_model_about.append (_ ("About"), "app.about");

                //
                var menu_model_quit = new Menu ();
                menu_model_quit.append (_ ("Quit"), "app.quit");

                //
                var menu_model = new Menu ();
                menu_model.append (_ ("Preferences"), "app.preferences");
                menu_model.append_section (null, menu_model_about);
                menu_model.append_section (null, menu_model_quit);

                menu.set_menu_model (menu_model);

                headerBar.pack_end (menu);
            }

            //
            var viewStack = new Adw.ViewStack ();
            viewStack.set_vexpand (true);
            append (viewStack);

            //
            var toolsPage = viewStack.add_titled (new Windows.Tools.LauncherSelector (leaflet, toastOverlay, notebook), _ ("Tools"), _ ("Tools"));
            toolsPage.set_icon_name ("emblem-system-symbolic");

            //
            var gamesPage = viewStack.add_titled (new Windows.Games.Main (), _ ("Games"), _ ("Games"));
            gamesPage.set_icon_name ("input-gaming-symbolic");

            //
            var notificationsPage = viewStack.add_titled (new Windows.Notifications.Main (), _ ("Notifications"), _ ("Notifications"));
            notificationsPage.set_icon_name ("application-rss+xml-symbolic");

            //
            if (GLib.Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland") {
                var preferencesPage = viewStack.add_titled (new Windows.Preferences.Main (notebook, toastOverlay), _ ("Preferences"), _ ("Preferences"));
                preferencesPage.set_icon_name ("preferences-other-symbolic");
            }

            //
            var toolsViewBar = new Adw.ViewSwitcherBar ();
            toolsViewBar.set_stack (viewStack);
            append (toolsViewBar);

            //
            var toolsViewTitle = new Adw.ViewSwitcherTitle ();
            toolsViewTitle.set_stack (viewStack);
            toolsViewTitle.notify.connect (() => {
                toolsViewBar.set_reveal (toolsViewTitle.get_title_visible ());
            });
            headerBar.set_title_widget (toolsViewTitle);
        }
    }
}
