namespace Windows {
    public class ViewManager : Gtk.Box {
        public ViewManager (Adw.Leaflet leaflet, Adw.ToastOverlay toastOverlay) {
            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            // Setup headerBar
            var headerBar = new Adw.HeaderBar ();
            headerBar.set_centering_policy (Adw.CenteringPolicy.STRICT);
            append (headerBar);

            // Setup menu
            var menu = new Gtk.MenuButton ();
            menu.set_icon_name ("open-menu-symbolic");

            // Setup menu_model_about
            var menu_model_about = new Menu ();
            menu_model_about.append (_("Telegram"), "app.telegram");
            menu_model_about.append (_("Documentation"), "app.documentation");
            menu_model_about.append (_("Donation"), "app.donation");
            menu_model_about.append (_("About"), "app.about");

            // Setup menu_model_quit
            var menu_model_quit = new Menu ();
            menu_model_quit.append (_("Quit"), "app.quit");

            // Setup menu_model
            var menu_model = new Menu ();
            menu_model.append (_("Preferences"), "app.preferences");
            menu_model.append_section (null, menu_model_about);
            menu_model.append_section (null, menu_model_quit);

            menu.set_menu_model (menu_model);

            headerBar.pack_end (menu);

            // Setup viewStack
            var viewStack = new Adw.ViewStack ();
            viewStack.set_vexpand (true);

            // Setup toolsPage
            var toolsPage = viewStack.add_titled (new Windows.Tools.LauncherSelector (leaflet, toastOverlay), _("Tools"), _("Tools"));
            toolsPage.set_icon_name ("emblem-system-symbolic");

            // Setup gamesPage
            var gamesPage = viewStack.add_titled (new Windows.Games.Main (), _("Games"), _("Games"));
            gamesPage.set_icon_name ("input-gaming-symbolic");

            // Setup notificationsPage
            var notificationsPage = viewStack.add_titled (new Windows.Notifications.Main (), _("Notifications"), _("Notifications"));
            notificationsPage.set_icon_name ("application-rss+xml-symbolic");

            // Add viewStack to boxMain
            append (viewStack);

            // Setup toolsViewBar
            var toolsViewBar = new Adw.ViewSwitcherBar ();
            toolsViewBar.set_stack (viewStack);
            append (toolsViewBar);

            // Setup toolsViewTitle
            var toolsViewTitle = new Adw.ViewSwitcherTitle ();
            toolsViewTitle.set_stack (viewStack);
            toolsViewTitle.notify.connect (() => {
                toolsViewBar.set_reveal (toolsViewTitle.get_title_visible ());
            });
            headerBar.set_title_widget (toolsViewTitle);
        }
    }
}
