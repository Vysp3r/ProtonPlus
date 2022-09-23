namespace ProtonPlus.Windows {
    public class HomeInfo : Gtk.Dialog {
        //Widgets
        Gtk.Box boxMain;
        Gtk.Label labelTool;
        Gtk.Label labelLauncher;
        Gtk.Label labelDirectory;
        Gtk.Widget btnClose;

        public HomeInfo (Gtk.ApplicationWindow parent, ProtonPlus.Models.CompatibilityTool.Release release, ProtonPlus.Models.Location location) {
            this.set_title ("About Compatibility Tool");
            this.set_default_size(500, 0);
            this.set_transient_for (parent);

            boxMain = this.get_content_area ();
            boxMain.set_orientation (Gtk.Orientation.VERTICAL);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            labelTool = new Gtk.Label("Compatibility tool: " + release.Label);
            boxMain.append(labelTool);

            labelLauncher = new Gtk.Label("Launcher: " + location.Launcher.Label);
            boxMain.append(labelLauncher);

            labelDirectory = new Gtk.Label("Install directory: " + location.InstallDirectory);
            boxMain.append(labelDirectory);

            btnClose = new Gtk.Button.with_label("Close");
            this.add_action_widget (btnClose, 0);

            // Show the window
            this.show();
        }
    }
}
