namespace ProtonPlus.Windows {
    public class LauncherSettings : Gtk.Dialog {
        // Values
        Models.Launcher currentLauncher;

        public LauncherSettings (Gtk.ApplicationWindow parent, Models.Launcher launcher) {
            set_transient_for (parent);
            set_modal (true);
            set_title (_ ("Launcher Settings"));
            set_default_size (430, 0);

            currentLauncher = launcher;

            // Setup boxMain
            var boxMain = this.get_content_area ();
            boxMain.set_orientation (Gtk.Orientation.VERTICAL);
            boxMain.set_spacing (15);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            // Setup btnClean
            var btnClean = new Gtk.Button.with_label (_ ("Clean launcher"));
            btnClean.set_tooltip_text (_ ("Delete every installed tools from the launcher"));
            btnClean.clicked.connect (btnClean_Clicked);
            boxMain.append (btnClean);

            // Show the window
            show ();
        }

        // Events
        void btnClean_Clicked () {
            new Widgets.ProtonMessageDialog (this, null, _ ("Are you sure you want to clean this launcher? WARNING: It will delete every installed tools from the launcher!"), Widgets.ProtonMessageDialog.MessageDialogType.NO_YES, (response) => {
                if (response == "yes") {
                    Utils.File.Delete (currentLauncher.Directory);
                    Utils.File.CreateDirectory (currentLauncher.Directory);

                    GLib.Timeout.add (1000, () => {
                        this.response (Gtk.ResponseType.APPLY);
                        return false;
                    }, 2);
                }
            });
        }
    }
}
