namespace ProtonPlus.Windows {
    public class Selector : Gtk.Dialog {
        // Widgets
        Gtk.Button btnInstall;
        Gtk.Button btnInfo;
        Adw.ComboRow crTools;
        Adw.ComboRow crReleases;
        Gtk.ProgressBar progressBarDownload;

        // Values
        Models.Launcher currentLauncher;
        Models.Tool currentTool;
        Models.Release currentRelease;
        Thread<int> downloadThread;
        Thread<void> extractThread;

        // Stores
        Stores.Threads store;

        public Selector (Gtk.ApplicationWindow parent, Models.Launcher launcher) {
            this.set_transient_for (parent);
            this.set_title ("Install Compatibility Tool");
            this.set_default_size (430, 0);

            this.currentLauncher = launcher;

            store = Stores.Threads.instance ();

            var boxMain = this.get_content_area ();
            boxMain.set_orientation (Gtk.Orientation.VERTICAL);
            boxMain.set_spacing (15);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            var factoryTools = new Gtk.SignalListItemFactory ();
            factoryTools.setup.connect (factoryTools_Setup);
            factoryTools.bind.connect (factoryTools_Bind);

            crTools = new Adw.ComboRow ();
            crTools.set_title ("Compatibility Tool");
            crTools.set_model (Models.Tool.GetStore (launcher.Tools));
            crTools.set_factory (factoryTools);
            crTools.notify.connect (crTools_Notify);

            var groupTools = new Adw.PreferencesGroup ();
            groupTools.add (crTools);
            boxMain.append (groupTools);

            btnInfo = new Gtk.Button.with_label ("Info");
            btnInstall = new Gtk.Button.with_label ("Install");

            crTools.notify_property ("selected");

            var factoryReleases = new Gtk.SignalListItemFactory ();
            factoryReleases.setup.connect (factoryReleases_Setup);
            factoryReleases.bind.connect (factoryReleases_Bind);

            crReleases = new Adw.ComboRow ();
            crReleases.set_title ("Version");
            crReleases.set_model (Models.Release.GetStore (Models.Release.GetReleases (currentTool)));
            crReleases.set_factory (factoryReleases);
            crReleases.notify.connect (crReleases_Notify);

            var groupReleases = new Adw.PreferencesGroup ();
            groupReleases.add (crReleases);
            boxMain.append (groupReleases);

            crReleases.notify_property ("selected");

            var boxBottom = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            boxBottom.set_hexpand (true);


            btnInfo.add_css_class ("pill");
            btnInfo.set_hexpand (true);
            btnInfo.clicked.connect (() => Gtk.show_uri (this, currentRelease.Page_URL, Gdk.CURRENT_TIME));
            boxBottom.append (btnInfo);

            btnInstall.add_css_class ("pill");
            btnInstall.set_hexpand (true);
            btnInstall.clicked.connect (btnInstall_Clicked);
            boxBottom.append (btnInstall);

            boxMain.append (boxBottom);

            progressBarDownload = new Gtk.ProgressBar ();
            progressBarDownload.set_visible (false);
            boxMain.append (progressBarDownload);

            this.show ();
        }

        void btnInstall_Clicked () {
            btnInstall.set_sensitive (false);
            progressBarDownload.set_visible (true);
            progressBarDownload.set_show_text (true);
            Download ();
        }

        void Download () {
            progressBarDownload.set_text ("Downloading...");
            downloadThread = new Thread<int> ("download", () => Manager.HTTP.Download (currentRelease.Download_URL, currentLauncher.Directory + "/" + currentRelease.Title + ".tar.gz"));
            GLib.Timeout.add (75, () => {
                progressBarDownload.set_fraction (store.ProgressBar);
                if (store.ProgressBar == 1) {
                    Extract ();
                    return false;
                }
                return true;
            }, 1);
        }

        void Extract () {
            progressBarDownload.set_text ("Extracting...");
            progressBarDownload.set_pulse_step (1);
            extractThread = new Thread<void> ("extract", () => {
                string sourcePath = Manager.File.Extract (currentLauncher.Directory + "/", currentRelease.Title);
                if (currentTool.Type != Models.Tool.TitleType.NONE) Manager.File.Rename (sourcePath, currentLauncher.Directory + "/" + currentRelease.GetFolderTitle (currentLauncher, currentTool));
                var store = Stores.Threads.instance ();
                store.ProgressBarDone = true;
            });
            GLib.Timeout.add (500, () => {
                progressBarDownload.pulse ();
                if (store.ProgressBarDone == true) {
                    progressBarDownload.set_text ("Done!");
                    progressBarDownload.set_fraction (store.ProgressBar = 0);
                    btnInstall.set_sensitive (true);
                    response (Gtk.ResponseType.APPLY);
                    return false;
                }
                return true;
            }, 1);
        }

        void crTools_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                currentTool = (Models.Tool) crTools.get_selected_item ();
                var releases = Models.Release.GetReleases (currentTool);
                if (releases.length () > 0) {
                    crReleases.set_model (Models.Release.GetStore (releases));
                } else {
                    crReleases.set_model (null);

                    var dialogMessage = new Adw.MessageDialog (this, null, "Could not fetch anything from the GitHub API. You may have reached the maximum amount of requests per hour. If you think this is a bug, please report this to us.");

                    dialogMessage.add_response ("ok", "Ok");
                    dialogMessage.set_response_appearance ("ok", Adw.ResponseAppearance.SUGGESTED);

                    dialogMessage.response.connect ((response) => {
                        this.close ();
                    });

                    dialogMessage.show ();
                }

                btnInfo.set_sensitive (releases.length () > 0);
                btnInstall.set_sensitive (releases.length () > 0);
            }
        }

        void factoryTools_Bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var string_holder = list_item.get_item () as Models.Tool;

            var title = list_item.get_data<Gtk.Label> ("title");
            title.label = string_holder.Title;
        }

        void factoryTools_Setup (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var title = new Gtk.Label ("");
            title.xalign = 0.0f;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.append (title);

            list_item.set_data ("title", title);
            list_item.set_child (box);
        }

        void crReleases_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                currentRelease = (Models.Release) crReleases.get_selected_item ();
            }
        }

        void factoryReleases_Bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var string_holder = list_item.get_item () as Models.Release;

            var title = list_item.get_data<Gtk.Label> ("title");
            title.label = string_holder.Title;
        }

        void factoryReleases_Setup (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var title = new Gtk.Label ("");
            title.xalign = 0.0f;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            box.append (title);

            list_item.set_data ("title", title);
            list_item.set_child (box);
        }
    }
}
