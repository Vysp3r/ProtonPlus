namespace ProtonPlus.Windows {
    public class Home : Adw.ApplicationWindow {
        public Home (Gtk.Application app) {
            set_application (app);
            set_title ("ProtonPlus");
            set_default_size (800, 500);

            // Setup boxMain
            var boxMain = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            set_content (boxMain);

            // Setup headerBar
            var headerBar = new Adw.HeaderBar ();
            headerBar.set_centering_policy (Adw.CenteringPolicy.STRICT);
            boxMain.append (headerBar);

            // Setup menu
            var menu = new Gtk.MenuButton ();
            menu.set_icon_name ("open-menu-symbolic");

            // Setup menu_model_about
            var menu_model_about = new Menu ();
            menu_model_about.append (_ ("Telegram"), "app.telegram");
            menu_model_about.append (_ ("Documentation"), "app.documentation");
            menu_model_about.append (_ ("Donation"), "app.donation");
            menu_model_about.append (_ ("About"), "app.about");

            // Setup menu_model_quit
            var menu_model_quit = new Menu ();
            menu_model_quit.append (_ ("Quit"), "app.quit");

            // Setup menu_model
            var menu_model = new Menu ();
            menu_model.append (_ ("Preferences"), "app.preferences");
            menu_model.append_section (null, menu_model_about);
            menu_model.append_section (null, menu_model_quit);

            menu.set_menu_model (menu_model);

            headerBar.pack_end (menu);

            // Setup viewStack
            var viewStack = new Adw.ViewStack ();
            viewStack.set_vexpand (true);

            // Setup toolsPage
            var toolsView = new Views.Tools (this);
            var toolsPage = viewStack.add_titled (toolsView.GetBox (), _ ("Tools"), _ ("Tools"));
            toolsPage.set_icon_name ("emblem-system-symbolic");

            // Setup gamesPage
            var gamesView = new Views.Games ();
            var gamesPage = viewStack.add_titled (gamesView.GetBox (), _ ("Games"), _ ("Games"));
            gamesPage.set_icon_name ("input-gaming-symbolic");

            // Setup notificationsPage
            var notificationsView = new Views.Notifications ();
            var notificationsPage = viewStack.add_titled (notificationsView.GetBox (), _ ("Notifications"), _ ("Notifications"));
            notificationsPage.set_icon_name ("preferences-desktop-locale-symbolic");

            // Add viewStack to boxMain
            boxMain.append (viewStack);

            // Setup toolsViewBar
            var toolsViewBar = new Adw.ViewSwitcherBar ();
            toolsViewBar.set_stack (viewStack);
            boxMain.append (toolsViewBar);

            // Setup toolsViewTitle
            var toolsViewTitle = new Adw.ViewSwitcherTitle ();
            toolsViewTitle.set_stack (viewStack);
            toolsViewTitle.notify.connect (() => {
                toolsViewBar.set_reveal (toolsViewTitle.get_title_visible ());
            });
            headerBar.set_title_widget (toolsViewTitle);

            // Show the window
            show ();
        }
    }
}
