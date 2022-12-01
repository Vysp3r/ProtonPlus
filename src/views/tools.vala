namespace ProtonPlus.Views {
    public class Tools {
        // Widgets
        Gtk.ApplicationWindow window;
        Gtk.Box boxMain;
        Adw.ComboRow crInstallLocation;
        Gtk.ListBox listInstalledTools;
        Gtk.Button btnAdd;

        // Values
        GLib.List<Models.Launcher> launchers;
        Models.Launcher currentLauncher;

        public Tools (Gtk.ApplicationWindow window) {
            this.window = window;
            this.launchers = Models.Launcher.GetAll ();
        }

        public Gtk.Box GetBox () {
            // Get the box child from the window
            boxMain = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            crInstallLocation = new Adw.ComboRow ();
            btnAdd = new Gtk.Button ();
            listInstalledTools = new Gtk.ListBox ();

            // Create a factory
            var factoryInstallLocation = new Gtk.SignalListItemFactory ();
            factoryInstallLocation.setup.connect (factoryInstallLocation_Setup);
            factoryInstallLocation.bind.connect (factoryInstallLocation_Bind);

            // Create a comborow
            crInstallLocation.notify.connect (crInstallLocation_Notify);
            crInstallLocation.set_title ("Launcher");
            crInstallLocation.set_model (Models.Launcher.GetStore (launchers));
            crInstallLocation.set_factory (factoryInstallLocation);

            // Create a group with crInstallLocation in it
            var groupInstallLocation = new Adw.PreferencesGroup ();
            groupInstallLocation.add (crInstallLocation);

            // Add groupInstallLocation to boxMain
            boxMain.append (groupInstallLocation);

            // Create a button
            btnAdd.set_icon_name ("tab-new-symbolic");
            btnAdd.add_css_class ("flat");
            btnAdd.add_css_class ("bold");
            btnAdd.clicked.connect (btnAdd_Clicked);

            // Create an ActionRow with a label and a button
            var rowInstalledTools = new Adw.ActionRow ();
            rowInstalledTools.set_title ("Installed Tools");
            rowInstalledTools.add_suffix (btnAdd);

            // Create a group with rowInstalledTools in it
            var groupInstalledTools = new Adw.PreferencesGroup ();
            groupInstalledTools.add (rowInstalledTools);

            // Add groupInstalledTools to boxMain
            boxMain.append (groupInstalledTools);

            // Create a listbox
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
        void crInstallLocation_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                currentLauncher = (Models.Launcher) crInstallLocation.get_selected_item ();
                var releases = Models.Release.GetInstalled (currentLauncher);
                var model = Models.Release.GetStore (releases);
                listInstalledTools.bind_model (model, (item) => {
                    var release = (Models.Release) item;

                    var row = new Adw.ActionRow ();
                    row.set_title (release.Title);

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

                btnAdd.set_sensitive (currentLauncher != null);
            }
        }

        void btnAdd_Clicked () {
            var dialogAddVersion = new Windows.Selector (window, currentLauncher);
            dialogAddVersion.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.APPLY) crInstallLocation.notify_property ("selected");
                if (response_id == Gtk.ResponseType.CANCEL) dialogAddVersion.close ();
            });
        }

        void btnInfo_Clicked (Models.Release release) {
            var dialogShowVersion = new Windows.HomeInfo (window, release, currentLauncher);
            dialogShowVersion.response.connect ((response_id) => {
                dialogShowVersion.close ();
            });
        }

        void btnDelete_Clicked (Models.Release release) {
            var dialogDeleteSelectedTest = new Adw.MessageDialog (window, null, "Are you sure you want to remove the selected version?");

            dialogDeleteSelectedTest.add_response ("no", "No");
            dialogDeleteSelectedTest.set_response_appearance ("no", Adw.ResponseAppearance.SUGGESTED);
            dialogDeleteSelectedTest.add_response ("yes", "Yes");
            dialogDeleteSelectedTest.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);

            dialogDeleteSelectedTest.response.connect ((response) => {
                if (response == "yes") {
                    GLib.Timeout.add (1000, () => {
                        Posix.system ("rm -rf \"" + currentLauncher.Directory + "/" + release.Title + "\"");
                        crInstallLocation.notify_property ("selected");
                        return false;
                    }, 2);
                }
            });

            dialogDeleteSelectedTest.show ();
        }

        void factoryInstallLocation_Bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var string_holder = list_item.get_item () as Models.Launcher;

            var title = list_item.get_data<Gtk.Label> ("title");
            title.set_label (string_holder.Title);
        }

        void factoryInstallLocation_Setup (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var title = new Gtk.Label ("");

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.append (title);

            list_item.set_data ("title", title);
            list_item.set_child (box);
        }
    }
}
