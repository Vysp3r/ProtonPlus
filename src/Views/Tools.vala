namespace ProtonPlus.Views {
    public class Tools : Interfaces.IView {
        // Widgets
        Gtk.ApplicationWindow window;
        Widgets.ProtonComboRow crInstallLocation;
        Gtk.ListBox listInstalledTools;
        Gtk.Button btnAdd;
        Gtk.Button btnInfoLauncher;
        Gtk.Button btnSettings;

        // Values
        GLib.List<Models.Launcher> launchers;
        Models.Launcher currentLauncher;
        Stores.Preferences preferences;
        bool firstRun;

        public Tools (Gtk.ApplicationWindow window, ref Stores.Preferences preferences) {
            this.window = window;
            this.preferences = preferences;
            this.launchers = Models.Launcher.GetAll (true);
            this.firstRun = true;
        }

        public Gtk.Box GetBox () {
            // Initialize shared widgets
            crInstallLocation = new Widgets.ProtonComboRow (_ ("Launcher"), Models.Launcher.GetStore (launchers));
            btnAdd = new Gtk.Button ();
            btnInfoLauncher = new Gtk.Button ();
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

            // Setup btnInfoLauncher
            btnInfoLauncher.set_icon_name ("dialog-information-symbolic");
            btnInfoLauncher.add_css_class ("flat");
            btnInfoLauncher.add_css_class ("bold");
            btnInfoLauncher.width_request = 50;
            btnInfoLauncher.set_tooltip_text (_ ("Launcher information"));
            btnInfoLauncher.clicked.connect (btnInfoLauncher_Clicked);

            // Setup btnSettings
            btnSettings.set_icon_name ("preferences-system-symbolic");
            btnSettings.add_css_class ("flat");
            btnSettings.add_css_class ("bold");
            btnSettings.width_request = 50;
            btnSettings.set_tooltip_text (_ ("Launcher settings"));
            btnSettings.clicked.connect (btnLauncherSettings_Clicked);

            // Setup btnAdd
            btnAdd.set_icon_name ("tab-new-symbolic");
            btnAdd.add_css_class ("flat");
            btnAdd.add_css_class ("bold");
            btnAdd.width_request = 50;
            btnAdd.set_tooltip_text (_ ("Install a tool"));
            btnAdd.clicked.connect (btnAdd_Clicked);

            // Setup boxActions
            var boxActions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            boxActions.add_css_class ("card");
            boxActions.append (btnInfoLauncher);
            boxActions.append (btnSettings);
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
            var position = Models.Launcher.GetPosition (launchers, preferences.LastLauncher);
            if (position > 0 && preferences.RememberLastLauncher) {
                crInstallLocation.set_selected (position);
            } else {
                crInstallLocation.notify_property ("selected");
            }

            // Show the window
            return boxMain;
        }

        // Events
        void crInstallLocation_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                currentLauncher = (Models.Launcher) crInstallLocation.get_selected_item ();

                if (preferences.LastLauncher != currentLauncher.Title) {
                    preferences.LastLauncher = currentLauncher.Title;
                    Utils.Preference.Update (ref preferences);
                }

                var releases = Models.Release.GetInstalled (currentLauncher);
                var model = Models.Release.GetStore (releases);
                listInstalledTools.bind_model (model, (item) => {
                    var release = (Models.Release) item;

                    var row = new Adw.ActionRow ();
                    row.set_title (release.Title);

                    var btnInfoTool = new Gtk.Button ();
                    btnInfoTool.set_icon_name ("dialog-information-symbolic");
                    btnInfoTool.add_css_class ("flat");
                    btnInfoTool.width_request = 50;
                    btnInfoTool.set_tooltip_text (_ ("Show information"));
                    btnInfoTool.clicked.connect (() => btnInfoTool_Clicked (release));
                    row.add_suffix (btnInfoTool);

                    var btnDelete = new Gtk.Button ();
                    btnDelete.add_css_class ("flat");
                    btnDelete.set_icon_name ("user-trash-symbolic");
                    btnDelete.width_request = 50;
                    btnDelete.set_tooltip_text (_ ("Delete the tool"));
                    btnDelete.clicked.connect (() => btnDelete_Clicked (release));
                    row.add_suffix (btnDelete);

                    return row;
                });

                btnSettings.set_sensitive (currentLauncher != null);
                btnAdd.set_sensitive (currentLauncher != null);
            }
        }

        void btnAdd_Clicked () {
            var dialogAdd = new Windows.InstallTool (window, currentLauncher);
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

        void btnInfoTool_Clicked (Models.Release release) {
            var dialogShowVersion = new Windows.AboutTool (window, release.Title, currentLauncher.Directory + "/" + release.Title);
            dialogShowVersion.response.connect ((response_id) => {
                dialogShowVersion.close ();
            });
        }

        void btnInfoLauncher_Clicked () {
            var dialogShowVersion = new Windows.AboutTool (window, currentLauncher.Title, currentLauncher.Directory);
            dialogShowVersion.response.connect ((response_id) => {
                dialogShowVersion.close ();
            });
        }

        void btnDelete_Clicked (Models.Release release) {
            var dialogDelete = new Widgets.ProtonMessageDialog (window, null, _ ("Are you sure you want to delete the selected tool?"), Widgets.ProtonMessageDialog.MessageDialogType.NO_YES, null);
            dialogDelete.response.connect ((response) => {
                if (response == "yes") {
                    GLib.Timeout.add (1000, () => {
                        Utils.File.Delete (currentLauncher.Directory + "/" + release.Title);
                        crInstallLocation.notify_property ("selected");
                        return false;
                    }, 2);
                }
            });
        }
    }
}
