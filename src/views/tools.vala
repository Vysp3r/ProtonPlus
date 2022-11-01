namespace ProtonPlus.Views {
    public class Tools  {
        // Widgets
        Gtk.ApplicationWindow window;
        Gtk.Box boxMain;
        Adw.ComboRow crInstallLocation;
        Gtk.ListBox listInstalledTools;

        // Values
        ProtonPlus.Models.Location currentLocation;

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

            // Create a factory
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect (factory_Setup);
            factory.bind.connect (factory_Bind);

            // Create a comborow
            crInstallLocation = new Adw.ComboRow ();
            crInstallLocation.notify.connect (crInstallLocation_Notify);
            crInstallLocation.set_title ("Install location");
            crInstallLocation.set_model (ProtonPlus.Models.Location.GetStore ());
            crInstallLocation.set_selected (0);
            crInstallLocation.set_factory (factory);

            // Create a group with crInstallLocation in it
            var groupInstallLocation = new Adw.PreferencesGroup ();
            groupInstallLocation.add(crInstallLocation);

            // Add groupInstallLocation to boxMain
            boxMain.append (groupInstallLocation);

            // Create a button
            var btnAdd = new Gtk.Button ();
            btnAdd.set_icon_name ("tab-new-symbolic");
            btnAdd.add_css_class ("flat");
            btnAdd.add_css_class ("bold");
            btnAdd.clicked.connect (btnAdd_Clicked);

            // Create an ActionRow with a label and a button
            var rowInstalledTools = new Adw.ActionRow ();
            rowInstalledTools.set_title ("Installed compatibility tools");
            rowInstalledTools.add_suffix (btnAdd);

            // Create a group with rowInstalledTools in it
            var groupInstalledTools = new Adw.PreferencesGroup ();
            groupInstalledTools.add (rowInstalledTools);

            // Add groupInstalledTools to boxMain
            boxMain.append (groupInstalledTools);

            // Create a listbox
            listInstalledTools = new Gtk.ListBox ();
            listInstalledTools.set_vexpand (true);
            listInstalledTools.add_css_class ("boxed-list");

            // Add listInstalledTools to boxMain
            boxMain.append (listInstalledTools);

            // Load the default values
            crInstallLocation.notify_property ("selected");

            // Show the window
            return boxMain;
        }

        // Events
        public void crInstallLocation_Notify (GLib.ParamSpec param) {
            if(param.get_name () == "selected"){
                currentLocation = (ProtonPlus.Models.Location) crInstallLocation.get_selected_item ();
                var releases = ProtonPlus.Models.CompatibilityTool.Installed (currentLocation);
                var model = ProtonPlus.Models.CompatibilityTool.Release.GetModel (releases);
                listInstalledTools.bind_model (model, (item) => {
                    var release = (ProtonPlus.Models.CompatibilityTool.Release) item;

                    var row = new Adw.ActionRow ();
                    row.set_title (release.Label);

                    var btnInfo = new Gtk.Button ();
                    btnInfo.set_icon_name ("dialog-information-symbolic");
                    btnInfo.add_css_class ("flat");
                    btnInfo.clicked.connect (() => btnInfo_Clicked (release));
                    row.add_suffix (btnInfo);

                    var btnDelete = new Gtk.Button ();
                    btnDelete.add_css_class ("flat");
                    btnDelete.set_icon_name ("user-trash-symbolic");
                    btnDelete.clicked.connect (() => btnDelete_Clicked (release));
                    row.add_suffix (btnDelete);

                    return row;
                });
            }
        }

        void btnAdd_Clicked () {
            var dialogAddVersion = new ProtonPlus.Windows.Selector (window, currentLocation);
            dialogAddVersion.response.connect ((response_id) => {
               if (response_id == Gtk.ResponseType.APPLY) crInstallLocation.notify_property ("selected");
               if (response_id == Gtk.ResponseType.CANCEL) dialogAddVersion.close ();
            });
        }

        void btnInfo_Clicked (ProtonPlus.Models.CompatibilityTool.Release release) {
            var dialogShowVersion = new ProtonPlus.Windows.HomeInfo (window, release, currentLocation);
            dialogShowVersion.response.connect ((response_id) => {
               dialogShowVersion.close ();
            });
        }

        void btnDelete_Clicked (ProtonPlus.Models.CompatibilityTool.Release release) {
            var dialogDeleteSelected = new Gtk.MessageDialog (window, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO, "Are you sure you want to remove the selected version?");
            dialogDeleteSelected.response.connect ((response_id) => {
                if (response_id == -8) {
                    Posix.system ("rm -rf " + currentLocation.InstallDirectory + "/" + release.Label);
                    crInstallLocation.notify_property ("selected");
                }

                dialogDeleteSelected.close ();
            });
            dialogDeleteSelected.show ();
        }

        void factory_Setup (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var string_holder = list_item.get_item () as ProtonPlus.Models.Location;

            var title = list_item.get_data<Gtk.Label>("Label");

            title.label = string_holder.Label;
        }

        void factory_Bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);

            var title = new Gtk.Label ("");
            title.xalign = 0.0f;

            box.append (title);

            list_item.set_data ("Label", title);
            list_item.set_child (box);
        }
    }
}
