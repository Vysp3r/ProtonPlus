namespace ProtonPlus.Launcher {
    public class LauncherWarningBox : Gtk.Box {
        construct {
            //
            this.set_orientation (Gtk.Orientation.VERTICAL);
            this.set_hexpand (true);
            this.set_vexpand (true);

            //
            var title = new Adw.WindowTitle ("", "");

            //
            var header = new Adw.HeaderBar ();
            header.add_css_class ("flat");
            header.set_show_start_title_buttons (false);
            header.set_title_widget (title);

            //
            var status = new Adw.StatusPage ();
            status.set_vexpand (true);
            status.set_title ("Welcome to " + Shared.Constants.APP_NAME);
            status.set_description ("Install Steam, Lutris, Bottles or Heroic Games Launcher to get started.");
            status.set_icon_name ("application-x-executable-symbolic");

            //
            append (header);
            append (status);
        }
    }
}