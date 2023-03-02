namespace Windows {
    public class Installer : Gtk.Dialog {
        // Widgets
        Gtk.Button btnInstall;
        Gtk.Button btnInfo;
        Widgets.ProtonComboRow crTools;
        Widgets.ProtonComboRow crReleases;
        Gtk.ProgressBar progressBarDownload;
        Thread<void> installThread;

        // Stores
        Stores.Main mainStore;

        public Installer (Gtk.ApplicationWindow parent, Models.Launcher launcher) {
            set_transient_for (parent);
            set_modal (true);
            set_title (_ ("Install"));
            set_default_size (430, 0);

            mainStore = Stores.Main.get_instance ();

            // Initialize shared widgets
            crTools = new Widgets.ProtonComboRow (_ ("Compatibility Tool"), Models.Tool.GetStore (mainStore.CurrentLauncher.Tools));
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
            btnInfo.clicked.connect (() => Gtk.show_uri (this, mainStore.CurrentRelease.Page_URL, Gdk.CURRENT_TIME));
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

            if (mainStore.CurrentTool.IsActions) progressBarDownload.set_pulse_step (1);

            installThread  = new Thread<void> ("download", () => {
                var store = Stores.Main.get_instance ();

                if (store.CurrentTool.IsActions) {
                    Utils.Web.OldDownload (store.CurrentRelease.Download_URL, store.CurrentLauncher.Directory + "/" + store.CurrentRelease.Title + store.CurrentRelease.File_Extension);
                } else {
                    Utils.Web.Download (store.CurrentRelease.Download_URL, store.CurrentLauncher.Directory + "/" + store.CurrentRelease.Title + store.CurrentRelease.File_Extension);
                }

                store.IsDownloadCompleted = true;
            });

            int timeout_refresh = 75;
            if (mainStore.CurrentTool.IsActions) timeout_refresh = 500;

            GLib.Timeout.add (timeout_refresh, () => {
                if (mainStore.IsInstallationCancelled) {
                    CancelInstallation ();
                    return false;
                }

                if (mainStore.CurrentTool.IsActions) progressBarDownload.pulse ();
                else progressBarDownload.set_fraction (mainStore.ProgressBarValue);

                if (mainStore.IsDownloadCompleted) {
                    Extract();
                    return false;
                }

                return true;
            }, 1);
        }

        void Extract () {
            progressBarDownload.set_text (_ ("Extracting..."));
            progressBarDownload.set_pulse_step (1);

            installThread = new Thread<void> ("extract", () => {
                var store = Stores.Main.get_instance ();

                string directory = store.CurrentLauncher.Directory + "/";
                string sourcePath = Utils.File.Extract (directory, store.CurrentRelease.Title, store.CurrentRelease.File_Extension);

                if (store.CurrentTool.IsActions) {
                    Utils.File.Extract (directory, sourcePath.substring (0, sourcePath.length - 4).replace (directory, ""), ".tar");
                }

                if (store.CurrentTool.Type != Models.Tool.TitleType.NONE) {
                    Utils.File.Rename (sourcePath, store.CurrentLauncher.Directory + "/" + store.CurrentRelease.GetFolderTitle (store.CurrentLauncher, store.CurrentTool));

                    GLib.Timeout.add (1000, () => {
                        if (Utils.File.Exists (store.CurrentLauncher.Directory + "/" + store.CurrentRelease.GetFolderTitle (store.CurrentLauncher, store.CurrentTool))) return false;

                        return true;
                    }, 1);
                }

                Stores.Main.get_instance ().IsExtractionCompleted = true;
            });

            GLib.Timeout.add (500, () => {
                if (mainStore.IsInstallationCancelled) {
                    CancelInstallation ();
                    return false;
                }

                progressBarDownload.pulse ();
                if (mainStore.IsExtractionCompleted == true) {
                    progressBarDownload.set_text (_ ("Done!"));
                    progressBarDownload.set_fraction (mainStore.ProgressBarValue = 0);
                    btnInstall.set_sensitive (true);
                    crReleases.set_sensitive (true);
                    crTools.set_sensitive (true);
                    response (Gtk.ResponseType.APPLY);

                    // Reset stores values
                    mainStore.IsInstallationCancelled = false;
                    mainStore.IsDownloadCompleted = false;
                    mainStore.IsExtractionCompleted = false;
                    mainStore.ProgressBarValue = 0;

                    return false;
                }

                return true;
            }, 1);
        }

        void CancelInstallation () {
            progressBarDownload.set_fraction (0);
            progressBarDownload.set_text (_ ("Cancelled!"));
            btnInstall.set_sensitive (true);
            crReleases.set_sensitive (true);
            crTools.set_sensitive (true);
        }

        // Events
        public override bool close_request() {
            if(mainStore.ProgressBarValue == 0)
                return false;

            var dialogDelete = new Widgets.ProtonMessageDialog(mainStore.MainWindow, null, _ ("Are you sure you want to cancel the download ?"), Widgets.ProtonMessageDialog.MessageDialogType.NO_YES, null);
            dialogDelete.response.connect ((response) => {
                this.set_visible(true);
                if (response == "yes") {
                    mainStore.IsInstallationCancelled = true;
                    installThread.join();
                    mainStore.IsDownloadCompleted = false;
                    mainStore.IsExtractionCompleted = false;
                    mainStore.ProgressBarValue = 0;
                    this.destroy();
                }
            });

            return true;
        }

        void btnInstall_Clicked () {
            btnInstall.set_sensitive (false);
            crReleases.set_sensitive (false);
            crTools.set_sensitive (false);
            ShowProgressBar (true);
            Stores.Main.get_instance ().IsInstallationCancelled = false;

            Download ();
        }

        void crTools_Notify (GLib.ParamSpec param) {
            if (param.get_name () == "selected") {
                btnInfo.set_sensitive (false);
                btnInstall.set_sensitive (false);
                crReleases.set_model (null);
                crReleases.set_sensitive (false);
                crTools.set_sensitive (false);

                if (progressBarDownload.get_text () == _ ("Done!")) ShowProgressBar (false);

                mainStore.CurrentTool = (Models.Tool) crTools.get_selected_item ();
                new Thread<void> ("api", () => {
                    var store = Stores.Main.get_instance ();
                    store.Releases = Models.Release.GetReleases (mainStore.CurrentTool);
                    store.ReleaseRequestIsDone = true;
                });

                GLib.Timeout.add (1000, () => {
                    if (mainStore.ReleaseRequestIsDone) {
                        btnInfo.set_sensitive (mainStore.Releases.length () > 0);
                        btnInstall.set_sensitive (mainStore.Releases.length () > 0);
                        crReleases.set_sensitive (mainStore.Releases.length () > 0);
                        crTools.set_sensitive (true);

                        mainStore.ReleaseRequestIsDone = false;

                        if (mainStore.Releases.length () > 0) {
                            crReleases.set_model (Models.Release.GetStore (mainStore.Releases));
                        } else {
                            crReleases.set_model (null);

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
                mainStore.CurrentRelease = (Models.Release) crReleases.get_selected_item ();
                if (progressBarDownload.get_text () == _ ("Done!")) ShowProgressBar (false);
            }
        }

        void ShowProgressBar (bool show) {
            progressBarDownload.set_visible (show);
            progressBarDownload.set_show_text (show);
            progressBarDownload.set_text ("");
        }
    }
}
