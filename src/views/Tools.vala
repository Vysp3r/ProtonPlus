namespace ProtonPlus.Views {
    public class Tools : Interfaces.IView {
        // Widgets
        Gtk.ApplicationWindow window;
        Widgets.ProtonComboRow crInstallLocation;
        Gtk.ListBox listInstalledTools;
        Gtk.Button btnAdd;
        Gtk.Button btnClean;
        Gtk.Button btnSettings;

        // Values
        GLib.List<Models.Launcher> launchers;
        Models.Launcher currentLauncher;

        public Tools (Gtk.ApplicationWindow window) {
            this.window = window;
            this.launchers = Models.Launcher.GetAll ();
        }

        public Gtk.Box GetBox () {
            // Initialize shared widgets
            crInstallLocation = new Widgets.ProtonComboRow ("Launcher", Models.Launcher.GetStore (launchers));
            btnAdd = new Gtk.Button ();
            btnClean = new Gtk.Button ();
            btnSettings = new Gtk.Button ();
            listInstalledTools = new Gtk.ListBox ();

            // Get the box child from the window
            var boxMain = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            // Setup boxLaunchers
            var boxLaunchers = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);

            // Setup crInstallLocation
            crInstallLocation.notify.connect (crInstallLocation_Notify);

            // Create a group with crInstallLocation in it
            var groupInstallLocation = new Adw.PreferencesGroup ();
            groupInstallLocation.set_hexpand (true);
            groupInstallLocation.add (crInstallLocation);

            // Add groupInstallLocation to boxMain
            boxLaunchers.append (groupInstallLocation);

            // Setup btnClean
            btnClean.set_icon_name ("preferences-system-symbolic");
            btnClean.add_css_class ("flat");
            btnClean.add_css_class ("bold");
            btnClean.width_request = 50;
            btnClean.set_tooltip_text ("Launcher settings");
            btnClean.clicked.connect (btnLauncherSettings_Clicked);

            // Setup btnAdd
            btnAdd.set_icon_name ("tab-new-symbolic");
            btnAdd.add_css_class ("flat");
            btnAdd.add_css_class ("bold");
            btnAdd.width_request = 50;
            btnAdd.set_tooltip_text ("Install a new tool");
            btnAdd.clicked.connect (btnAdd_Clicked);

            // Setup boxActions
            var boxActions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            boxActions.add_css_class ("card");
            boxActions.append (btnClean);
            boxActions.append (btnAdd);

            // Add boxActions to boxLaunchers
            boxLaunchers.append (boxActions);

            // Add boxLaunchers to boxMain
            boxMain.append (boxLaunchers);

            // Setup listInstalledTools
            listInstalledTools.set_vexpand (true);
            listInstalledTools.add_css_class ("boxed-list");

            // Setup scrolledWindowInstalledTools
            var scrolledWindowInstalledTools = new Gtk.ScrolledWindow ();
            scrolledWindowInstalledTools.set_child (listInstalledTools);
            boxMain.append (scrolledWindowInstalledTools);

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

                btnClean.set_sensitive (currentLauncher != null);
                btnAdd.set_sensitive (currentLauncher != null);
            }
        }

        void btnAdd_Clicked () {
            var dialogAdd = new Windows.Selector (window, currentLauncher);
            dialogAdd.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.APPLY) crInstallLocation.notify_property ("selected");
                if (response_id == Gtk.ResponseType.CANCEL) dialogAdd.close ();
            });
        }

        void btnLauncherSettings_Clicked () {
            var dialogLauncherSettings = new Windows.LauncherSettings (window, currentLauncher);
            dialogLauncherSettings.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.APPLY) crInstallLocation.notify_property ("selected");
                if (response_id == Gtk.ResponseType.CANCEL) dialogLauncherSettings.close ();
            });
        }

        void btnInfo_Clicked (Models.Release release) {
            var dialogShowVersion = new Windows.AboutTool (window, release, currentLauncher);
            dialogShowVersion.response.connect ((response_id) => {
                dialogShowVersion.close ();
            });
        }

        void btnDelete_Clicked (Models.Release release) {
            new Widgets.ProtonMessageDialog (window, null, "Are you sure you want to delete the selected tool?", Widgets.ProtonMessageDialog.MessageDialogType.NO_YES, (response) => {
                if (response == "yes") {
                    GLib.Timeout.add (1000, () => {
                        Manager.File.Delete (currentLauncher.Directory + "/" + release.Title);
                        crInstallLocation.notify_property ("selected");
                        return false;
                    }, 2);
                }
            });
        }
    }
}
