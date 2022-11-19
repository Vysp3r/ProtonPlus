namespace ProtonPlus.Windows {
    public class Home : Adw.ApplicationWindow {
        public Home (Gtk.Application app) {
            this.set_application (app);
            this.set_title ("ProtonPlus");
            this.set_default_size (800, 500);

            // Create a box
            var boxMain = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            // Set the content of the window to boxMain
            this.set_content (boxMain);

            // Create an header bar
            var headerBar = new Adw.HeaderBar ();
            headerBar.set_centering_policy (Adw.CenteringPolicy.STRICT);

            // Add the header bar to boxMain
            boxMain.append (headerBar);

            // Create a menu button
            var menu = new Gtk.MenuButton ();
            menu.set_icon_name("open-menu-symbolic");

            // Create a menu
            var menu_model_about = new Menu();
            menu_model_about.append("_Telegram", "app.telegram");
            menu_model_about.append("_Documentation", "app.documentation");
            menu_model_about.append("_Donation", "app.donation");
            menu_model_about.append("_About", "app.about");

            // Create a menu
            var menu_model_quit = new Menu();
            menu_model_quit.append("_Quit", "app.quit");

            // Create a menu
            var menu_model = new Menu();
            menu_model.append("_Preferences", "app.preferences");
            menu_model.append_section(null, menu_model_about);
            menu_model.append_section(null, menu_model_quit);

            // Set the model of menu to menu_model
            menu.set_menu_model(menu_model);

            // Add menu to the end of headerBar
            headerBar.pack_end(menu);

            // Create a view stack
            var viewStack = new Adw.ViewStack ();
            viewStack.set_vexpand (true);

            // Add the Tools to viewStack
            var toolsView = new ProtonPlus.Views.Tools (this);
            var toolsPage = viewStack.add_titled (toolsView.GetBox (), "Tools", "Tools");
            toolsPage.set_icon_name ("emblem-system-symbolic");

            // Add the Games to viewStack
            var gamesPage = viewStack.add_titled (ProtonPlus.Views.Games.GetBox (), "Games", "Games");
            gamesPage.set_icon_name ("input-gaming-symbolic");

            // Add the Notifications to viewStack
            var notificationsPage = viewStack.add_titled (ProtonPlus.Views.Notifications.GetBox (), "Notifications", "Notifications");
            notificationsPage.set_icon_name ("preferences-desktop-locale-symbolic");

            // Add viewStack to boxMain
            boxMain.append (viewStack);

            var toolsViewBar = new Adw.ViewSwitcherBar ();
            toolsViewBar.set_stack (viewStack);

            boxMain.append (toolsViewBar);

            var toolsViewTitle = new Adw.ViewSwitcherTitle ();
            toolsViewTitle.set_stack (viewStack);
            toolsViewTitle.notify.connect (() => {
                toolsViewBar.set_reveal (toolsViewTitle.get_title_visible ());
            });
            headerBar.set_title_widget (toolsViewTitle);

            // Show the window
            this.show();
        }
    }
}

