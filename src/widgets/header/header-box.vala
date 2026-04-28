namespace ProtonPlus.Widgets.Header {
    public class Box : Gtk.Box {
        public signal void launcher_selected (Models.Launcher launcher);

        Adw.HeaderBar header_bar { get; set; }
        LaunchersButton launchers_button { get; set; }
        Gtk.MenuButton menu_button { get; set; }

        public Box () {
            launchers_button = new LaunchersButton ();
            launchers_button.launcher_selected.connect ((launcher) => launcher_selected (launcher));

            var menu = new Menu ();
            menu.append (_ ("_Preferences"), "app.preferences");
            menu.append (_ ("_Keyboard Shortcuts"), "win.show-help-overlay");
            menu.append (_ ("_Donate"), "app.donate");
            menu.append (_ ("_About ProtonPlus"), "app.about");

            menu_button = new Gtk.MenuButton ();
            menu_button.set_tooltip_text (_ ("Main Menu"));
            menu_button.set_icon_name ("bars-symbolic");
            menu_button.set_menu_model (menu);

            header_bar = new Adw.HeaderBar ();
            header_bar.pack_start (launchers_button);
            header_bar.pack_end (menu_button);
            header_bar.set_hexpand (true);


            append (header_bar);
        }

        public void initialize (Gee.LinkedList<Models.Launcher> launchers, Adw.ViewSwitcher view_switcher) {
            launchers_button.initialize (launchers);

            if (view_switcher.get_parent () == null)
            header_bar.set_title_widget (view_switcher);
        }

    }
}