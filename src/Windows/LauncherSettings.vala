namespace Windows {
    public class LauncherSettings : Gtk.Dialog {
        // Values
        Models.Launcher currentLauncher;
        Gtk.Button clean_launcher_button;
        bool cant_close;

        public LauncherSettings (Gtk.ApplicationWindow parent, Models.Launcher launcher) {
            cant_close = false;

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
            clean_launcher_button = new Gtk.Button.with_label (_ ("Clean launcher"));
            clean_launcher_button.set_tooltip_text (_ ("Delete every installed tools from the launcher"));
            clean_launcher_button.clicked.connect (btnClean_Clicked);
            boxMain.append (clean_launcher_button);

            // Show the window
            show ();
        }

        public override bool close_request(){
            return cant_close;
        }

        // Events
        void btnClean_Clicked () {
            new Widgets.ProtonMessageDialog (this, null, _ ("Are you sure you want to clean this launcher? WARNING: It will delete every installed tools from the launcher!"), Widgets.ProtonMessageDialog.MessageDialogType.NO_YES, (response) => {
                if (response == "yes") {
                    clean_launcher_button.set_sensitive(false);
                    cant_close = true;
                    new Thread<void> ("cleaning_thread", () => {
                        var dir = new Utils.DirUtil(currentLauncher.HomeDirectory);
                        dir.remove_dir(currentLauncher.Folder);
                        Utils.File.CreateDirectory (currentLauncher.Directory);
                        this.response (Gtk.ResponseType.APPLY);
                        clean_launcher_button.set_sensitive(true);
                        cant_close = false;
                    });
                }
            });
        }
    }
}
