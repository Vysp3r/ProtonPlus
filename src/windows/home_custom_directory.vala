namespace ProtonPlus.Windows {
    public class HomeCustomDirectory : Gtk.ApplicationWindow {
        //Widgets
        Gtk.Box boxMain;
        Gtk.Label labelDirectory;
        Gtk.Entry entryDirectory;
        Gtk.Label labelLauncher;
        ProtonPlus.Widgets.ProtonComboBox cbLaunchers;
        Gtk.Button btnSave;

        public HomeCustomDirectory (Gtk.Application app) {
            this.set_application (app);
            this.set_title ("Custom Install Directory");
            this.set_default_size(500, 0);

            boxMain = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
            boxMain.set_margin_bottom(15);
            boxMain.set_margin_end(15);
            boxMain.set_margin_start(15);
            boxMain.set_margin_top(15);

            this.set_child (boxMain);

            labelDirectory = new Gtk.Label.with_mnemonic("Directory");
            boxMain.append(labelDirectory);

            entryDirectory = new Gtk.Entry();
            boxMain.append(entryDirectory);

            labelLauncher = new Gtk.Label.with_mnemonic("Launcher");
            boxMain.append(labelLauncher);

            cbLaunchers = new ProtonPlus.Widgets.ProtonComboBox(ProtonPlus.Models.Launcher.GetModel());
            boxMain.append(cbLaunchers);

            btnSave = new Gtk.Button.with_label("Save");
            boxMain.append(btnSave);

            // Show the window
            this.show();
        }
    }
}
