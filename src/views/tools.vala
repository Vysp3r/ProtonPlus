namespace ProtonPlus.Views {
    public class Tools  {
        //Widgets
        Gtk.ApplicationWindow window;
        Gtk.Box boxMain;
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

        public Tools (Gtk.ApplicationWindow window) {
            this.window = window;
        }

        public Gtk.Box GetBox () {
            // Get the box child from the window
            boxMain = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
            boxMain.set_margin_bottom(15);
            boxMain.set_margin_end(15);
            boxMain.set_margin_start(15);
            boxMain.set_margin_top(15);

            //
            labelInstalledTools = new Gtk.Label("Install location");
            boxMain.append(labelInstalledTools);

            /*  */
            boxInstallLocation = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);

            cbInstallLocation = new ProtonPlus.Widgets.ProtonComboBox(ProtonPlus.Models.Location.GetModel());
            cbInstallLocation.set_hexpand(true);
            cbInstallLocation.GetChild ().changed.connect(cbInstallLocation_Changed);
            boxInstallLocation.append (cbInstallLocation);

            boxMain.append (boxInstallLocation);
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
            return boxMain;
        }

        private void btnAddVersion_Clicked () {
            var dialogAddVersion = new ProtonPlus.Windows.Selector (window, currentLocation);
            dialogAddVersion.response.connect ((response_id) => {
               if (response_id == Gtk.ResponseType.APPLY) cbInstallLocation_Changed ();
               if (response_id == Gtk.ResponseType.CANCEL) dialogAddVersion.close ();
            });
        }

        private void btnShowVersion_Clicked () {
            var dialogShowVersion = new ProtonPlus.Windows.HomeInfo (window, currentRelease, currentLocation);
            dialogShowVersion.response.connect ((response_id) => {
               dialogShowVersion.close ();
            });
        }

        private void btnRemoveSelected_Clicked () {
            var dialogRemoveSelected = new Gtk.MessageDialog (window, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO, "Are you sure you want to remove the selected version?");
            dialogRemoveSelected.response.connect ((response_id) => {
                if (response_id == -8) {
                    Posix.system ("rm -rf " + currentLocation.InstallDirectory + "/" + currentRelease.Label);
                    cbInstallLocation_Changed ();
                }

                dialogRemoveSelected.close ();
            });
            dialogRemoveSelected.show ();
        }

        public void cbInstallLocation_Changed () {
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
