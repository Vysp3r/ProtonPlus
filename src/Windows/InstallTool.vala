namespace ProtonPlus.Windows {
    public class InstallTool : Gtk.Dialog {
        // Widgets
        Gtk.Button btnInstall;
        Gtk.Button btnInfo;
        Widgets.ProtonComboRow crTools;
        Widgets.ProtonComboRow crReleases;
        Gtk.ProgressBar progressBarDownload;

        // Values
        Models.Launcher currentLauncher;
        Models.Tool currentTool;
        Models.Release currentRelease;
        Thread<int> downloadThread;
        Thread<void> extractThread;
        Thread<void> apiThread;

        // Stores
        Stores.Threads store;

        public InstallTool (Gtk.ApplicationWindow parent, Models.Launcher launcher) {
            set_transient_for (parent);
            set_title (_ ("Install"));
            set_default_size (430, 0);

            currentLauncher = launcher;
            store = Stores.Threads.instance ();

            // Initialize shared widgets
            crTools = new Widgets.ProtonComboRow (_ ("Compatibility Tool"), Models.Tool.GetStore (launcher.Tools));
            crReleases = new Widgets.ProtonComboRow (_ ("Version"));
            btnInfo = new Gtk.Button.with_label (_ ("Info"));
            btnInstall = new Gtk.Button.with_label (_ ("Install"));
            progressBarDownload = new Gtk.ProgressBar ();

            // Setup boxMain
            var boxMain = this.get_content_area ();
            boxMain.set_orientation (Gtk.Orientation.VERTICAL);
            boxMain.set_spacing (15);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            crTools.notify.connect (crTools_Notify);

            // Setup groupTools
            var groupTools = new Adw.PreferencesGroup ();
            groupTools.add (crTools);
            boxMain.append (groupTools);

            crTools.notify_property ("selected");

            crReleases.notify.connect (crReleases_Notify);

            // Setup groupReleases
            var groupReleases = new Adw.PreferencesGroup ();
            groupReleases.add (crReleases);
            boxMain.append (groupReleases);

            crReleases.notify_property ("selected");

            // Setup boxBottom
            var boxBottom = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            boxBottom.set_hexpand (true);

            // Setup btnInfo
            btnInfo.add_css_class ("pill");
            btnInfo.set_hexpand (true);
            btnInfo.set_sensitive (false);
            btnInfo.set_tooltip_text (_ ("Open a browser to the tool page"));
            btnInfo.clicked.connect (() => Gtk.show_uri (this, currentRelease.Page_URL, Gdk.CURRENT_TIME));
            boxBottom.append (btnInfo);

            // Setup btnInstall
            btnInstall.add_css_class ("pill");
            btnInstall.set_hexpand (true);
            btnInstall.set_sensitive (false);
            btnInstall.set_tooltip_text (_ ("Install the selected tool"));
            btnInstall.clicked.connect (btnInstall_Clicked);
            boxBottom.append (btnInstall);

            boxMain.append (boxBottom);

            // Setup progressBarDownload
            progressBarDownload.set_visible (false);
            boxMain.append (progressBarDownload);

            // Show the window
            show ();
        }

        void Download () {
            progressBarDownload.set_text (_ ("Downloading..."));
            downloadThread = new Thread<int> ("download", () => Utils.HTTP.Download (currentRelease.Download_URL, currentLauncher.Directory + "/" + currentRelease.Title + ".tar.gz"));
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
            progressBarDownload.set_text (_ ("Extracting..."));
            progressBarDownload.set_pulse_step (1);
            extractThread = new Thread<void> ("extract", () => {
                string sourcePath = Utils.File.Extract (currentLauncher.Directory + "/", currentRelease.Title);
                if (currentTool.Type != Models.Tool.TitleType.NONE) Utils.File.Rename (sourcePath, currentLauncher.Directory + "/" + currentRelease.GetFolderTitle (currentLauncher, currentTool));
                var store = Stores.Threads.instance ();
                store.ProgressBarDone = true;
            });
            GLib.Timeout.add (500, () => {
                progressBarDownload.pulse ();
                if (store.ProgressBarDone == true) {
                    progressBarDownload.set_text (_ ("Done!"));
                    progressBarDownload.set_fraction (store.ProgressBar = 0);
                    btnInstall.set_sensitive (true);
                    response (Gtk.ResponseType.APPLY);
                    return false;
                }
                return true;
            }, 1);
        }

        // Events
        void btnInstall_Clicked () {
            btnInstall.set_sensitive (false);
            progressBarDownload.set_visible (true);
            progressBarDownload.set_show_text (true);
            Download ();
        }

        void crTools_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                btnInfo.set_sensitive (false);
                btnInstall.set_sensitive (false);

                currentTool = (Models.Tool) crTools.get_selected_item ();
                apiThread = new Thread<void> ("api", () => {
                    var store = Stores.Threads.instance ();
                    store.Releases = Models.Release.GetReleases (currentTool);
                    store.ReleaseRequestDone = true;
                });

                GLib.Timeout.add (1000, () => {
                    if (store.ReleaseRequestDone) {
                        btnInfo.set_sensitive (store.Releases.length () > 0);
                        btnInstall.set_sensitive (store.Releases.length () > 0);

                        if (store.Releases.length () > 0) {
                            crReleases.set_model (Models.Release.GetStore (store.Releases));
                        } else {
                            crReleases.set_model (null);

                            btnInfo.set_sensitive (false);
                            btnInstall.set_sensitive (false);

                            new Widgets.ProtonMessageDialog (this, null, _ ("There was an error while fetching data from the GitHub API. You may have reached the maximum amount of requests per hour or may not be connected to the internet. If you think this is a bug, please report this to us."), Widgets.ProtonMessageDialog.MessageDialogType.OK, (response) => this.close ());
                        }

                        return false;
                    }
                    return true;
                }, 1);
            }
        }

        void crReleases_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                currentRelease = (Models.Release) crReleases.get_selected_item ();
            }
        }
    }
}
