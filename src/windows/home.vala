namespace ProtonPlus.Windows {
    public class Home : Gtk.ApplicationWindow {
        //Widgets
        Gtk.HeaderBar headerBar;
        Gtk.MenuButton menu;
        GLib.Menu menu_model_about;
        GLib.Menu menu_model_quit;
        GLib.Menu menu_model;
        Gtk.Box boxMain;
        Gtk.Label labelInstallLocation;
        Gtk.Box boxInstallLocation;
        ProtonPlus.Widgets.ProtonComboBox cbInstallLocation;
        Gtk.Label labelInstalledTools;
        Gtk.ListBox listInstalledTools;
        Gtk.Box boxActions;
        Gtk.Button btnAddVersion;
        Gtk.Button btnRemoveSelected;
        Gtk.Button btnShowVersion;

        //Values
        List<ProtonPlus.Models.CompatibilityTool.Release> releases;
        ProtonPlus.Models.Location currentLocation;
        ProtonPlus.Models.CompatibilityTool.Release currentRelease;

        public Home (Gtk.Application app) {
            this.set_application (app);
            this.set_title ("ProtonPlus");
            this.set_default_size (500, 400);

            // Create a titlebar
            headerBar = new Gtk.HeaderBar ();

            // Create a menu button with a custom icon
            menu = new Gtk.MenuButton ();
            menu.set_icon_name("open-menu-symbolic");

            menu_model_about = new Menu();
            menu_model_about.append("_Telegram", "app.telegram");
            menu_model_about.append("_Documentation", "app.documentation");
            menu_model_about.append("_Donation", "app.donation");
            menu_model_about.append("_About", "app.about");

            menu_model_quit = new Menu();
            menu_model_quit.append("_Quit", "app.quit");

            // Create a menu with items
            menu_model = new Menu();
            menu_model.append("_Preferences", "app.preferences");
            menu_model.append_section(null, menu_model_about);
            menu_model.append_section(null, menu_model_quit);

            // Set the menu button model to the created menu
            menu.set_menu_model(menu_model);

            // Add the menu button to the end of the titlebar
            headerBar.pack_end(menu);

            // Set the window titlebar to created titlebar
            this.set_titlebar(headerBar);

            // Get the box child from the window
            boxMain = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
            boxMain.set_margin_bottom(15);
            boxMain.set_margin_end(15);
            boxMain.set_margin_start(15);
            boxMain.set_margin_top(15);

            this.set_child (boxMain);

            //
            labelInstallLocation = new Gtk.Label("Install location");
            labelInstallLocation.set_vexpand(false);
            boxMain.append(labelInstallLocation);

            /*  */
            boxInstallLocation = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 15);

            cbInstallLocation = new ProtonPlus.Widgets.ProtonComboBox(ProtonPlus.Models.Location.GetModel());
            cbInstallLocation.set_hexpand(true);
            cbInstallLocation.GetChild ().changed.connect(cbInstallLocation_Changed);
            boxInstallLocation.append(cbInstallLocation);

            // var btnInstallLocation = new Gtk.Button();
            // btnInstallLocation.set_label("...");
            // btnInstallLocation.clicked.connect(() => Windows.HomeCustomDirectory.Show(app));
            // boxInstallLocation.append(btnInstallLocation);

            boxMain.append(boxInstallLocation);
            /*  */

            //
            labelInstalledTools = new Gtk.Label("Installed compatibility tools");
            boxMain.append(labelInstalledTools);

            //
            listInstalledTools = new Gtk.ListBox ();
            listInstalledTools.set_vexpand(true);
            listInstalledTools.row_selected.connect((row) => listInstalledTools_RowSelected(row));
            boxMain.append(listInstalledTools);

            currentLocation = (ProtonPlus.Models.Location) cbInstallLocation.GetCurrentObject ();
            releases = ProtonPlus.Models.CompatibilityTool.Installed (currentLocation);

            /*  */
            boxActions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 15);

            btnAddVersion = new Gtk.Button();
            btnAddVersion.set_label("Add version");
            btnAddVersion.set_hexpand(true);
            btnAddVersion.clicked.connect(btnAddVersion_Clicked);
            if (cbInstallLocation.GetChild().get_active() == -1) btnAddVersion.set_sensitive(false);
            boxActions.append(btnAddVersion);

            btnRemoveSelected = new Gtk.Button();
            btnRemoveSelected.set_label("Remove selected");
            btnRemoveSelected.set_hexpand(true);
            btnRemoveSelected.set_sensitive(false);
            btnRemoveSelected.clicked.connect(btnRemoveSelected_Clicked);
            boxActions.append(btnRemoveSelected);

            btnShowVersion = new Gtk.Button();
            btnShowVersion.set_label("Show info");
            btnShowVersion.set_hexpand(true);
            btnShowVersion.set_sensitive(false);
            btnShowVersion.clicked.connect(btnShowVersion_Clicked);
            boxActions.append(btnShowVersion);

            boxMain.append(boxActions);
            /*  */

            cbInstallLocation_Changed ();

            // Show the window
            this.show();
        }

        private void btnAddVersion_Clicked () {
            var dialogShowVersion = new ProtonPlus.Windows.Selector (this, currentLocation);
            dialogShowVersion.response.connect ((response_id) => {
               if (response_id == Gtk.ResponseType.APPLY) cbInstallLocation_Changed ();
               dialogShowVersion.close ();
            });
        }

        private void btnShowVersion_Clicked () {
            var dialogShowVersion = new ProtonPlus.Windows.HomeInfo (this, currentRelease, currentLocation);
            dialogShowVersion.response.connect ((response_id) => {
               dialogShowVersion.close ();
            });
        }

        private void btnRemoveSelected_Clicked () {
            var dialogRemoveSelected = new Gtk.MessageDialog (this, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO, "Are you sure you want to remove the selected version?");
            dialogRemoveSelected.response.connect ((response_id) => {
                if (response_id == -8) {
                    Posix.system ("rm -rf " + currentLocation.InstallDirectory + "/" + currentRelease.Label);
                    cbInstallLocation_Changed ();
                }

                dialogRemoveSelected.close ();
            });
            dialogRemoveSelected.show ();
        }

        private void cbInstallLocation_Changed () {
            currentLocation = (ProtonPlus.Models.Location) cbInstallLocation.GetCurrentObject ();
            releases = ProtonPlus.Models.CompatibilityTool.Installed (currentLocation);
            var model = ProtonPlus.Models.CompatibilityTool.Release.GetModel (releases);
            listInstalledTools.bind_model (model, (item) => {
                var release = (ProtonPlus.Models.CompatibilityTool.Release) item;
                return new ProtonPlus.Widgets.ProtonRow<ProtonPlus.Models.CompatibilityTool.Release> (release.Label, release);
            });
        }

        private void listInstalledTools_RowSelected (Gtk.ListBoxRow row) {
            bool valid = true;

            if (row == null) valid = false;

            if (valid) {
                ProtonPlus.Widgets.ProtonRow<ProtonPlus.Models.CompatibilityTool.Release> pRow = (ProtonPlus.Widgets.ProtonRow) row.child;
                currentRelease = pRow.GetCurrentObject ();

                if (currentRelease == null) valid = false;
            }

            btnShowVersion.set_sensitive (valid);
            btnRemoveSelected.set_sensitive (valid);
        }
    }
}
