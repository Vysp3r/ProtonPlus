namespace ProtonPlus.Windows {
    public class HomeInfo : Gtk.Dialog {
        public HomeInfo (Gtk.ApplicationWindow parent, ProtonPlus.Models.Release release, ProtonPlus.Models.Launcher launcher) {
            set_title ("About");
            set_default_size (500, 0);
            set_transient_for (parent);

            // Setup boxMain
            var boxMain = this.get_content_area ();
            boxMain.set_orientation (Gtk.Orientation.VERTICAL);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            // Setup labelTool
            var labelTool = new Gtk.Label ("Tool: " + release.Title);
            boxMain.append (labelTool);

            // Setup labelLauncher
            var labelLauncher = new Gtk.Label ("Launcher: " + launcher.Title);
            boxMain.append (labelLauncher);

            // Setup labelDirectory
            var labelDirectory = new Gtk.Label ("Directory: " + launcher.Directory);
            boxMain.append (labelDirectory);

            // Setup btnClose
            var btnClose = new Gtk.Button.with_label ("Close");
            this.add_action_widget (btnClose, 0);

            // Show the window
            show ();
        }
    }
}
