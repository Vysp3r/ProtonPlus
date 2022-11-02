namespace ProtonPlus.Windows {
    public class Selector : Gtk.Dialog {
        //Widgets
        Gtk.Box boxMain;
        Gtk.Label labelTools;
        ProtonPlus.Widgets.ProtonComboBox cbTools;
        Gtk.Label labelReleases;
        ProtonPlus.Widgets.ProtonComboBox cbReleases;
        Gtk.Label labelDescription;
        Gtk.Entry entryDescription;
        Gtk.Box boxBottom;
        Gtk.Button btnInfo;
        Gtk.Button btnInstall;
        Gtk.Button btnCancel;
        Gtk.ProgressBar progressBarDownload;

        //Values
        ProtonPlus.Models.Location location;
        ProtonPlus.Models.CompatibilityTool currentTool;
        ProtonPlus.Models.CompatibilityTool.Release currentRelease;

        //Stores
        ProtonPlus.Stores.Threads store;

        public Selector (Gtk.ApplicationWindow parent, ProtonPlus.Models.Location location) {
            this.set_transient_for (parent);
            this.set_title("Install Compatibility Tool");
            this.set_default_size (500, 0);

            this.location = location;

            store = ProtonPlus.Stores.Threads.instance ();

            boxMain = this.get_content_area ();
            boxMain.set_orientation (Gtk.Orientation.VERTICAL);
            boxMain.set_spacing (15);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            labelTools = new Gtk.Label ("Compatibility Tool");
            labelTools.add_css_class ("bold");
            boxMain.append (labelTools);

            cbTools = new ProtonPlus.Widgets.ProtonComboBox (ProtonPlus.Models.CompatibilityTool.GetModel (location.Tools));
            boxMain.append (cbTools);

            labelReleases = new Gtk.Label ("Version");
            labelReleases.add_css_class ("bold");
            boxMain.append (labelReleases);

            currentTool = (ProtonPlus.Models.CompatibilityTool) cbTools.GetCurrentObject ();
            cbReleases = new ProtonPlus.Widgets.ProtonComboBox (ProtonPlus.Models.CompatibilityTool.GetReleasesModel (currentTool.GetReleases ()));
            cbReleases.GetChild ().changed.connect (cbReleases_Changed);
            boxMain.append (cbReleases);

            labelDescription = new Gtk.Label ("Description");
            labelDescription.add_css_class ("bold");
            boxMain.append (labelDescription);

            entryDescription = new Gtk.Entry ();
            entryDescription.set_editable (false);
            entryDescription.set_vexpand (true);
            entryDescription.set_text (currentTool.Description);
            boxMain.append (entryDescription);

            progressBarDownload = new Gtk.ProgressBar ();
            cbTools.GetChild ().changed.connect (cbTools_Changed);

            boxBottom = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            boxBottom.set_hexpand (true);

            cbReleases_Changed ();

            btnInfo = new Gtk.Button.with_label ("Info");
            btnInfo.set_hexpand (true);
            btnInfo.clicked.connect (() => Gtk.show_uri (this, currentRelease.Page_URL, Gdk.CURRENT_TIME));
            boxBottom.append (btnInfo);

            btnInstall = new Gtk.Button.with_label ("Install");
            btnInstall.set_hexpand (true);
            btnInstall.clicked.connect (btnInstall_Clicked);
            boxBottom.append (btnInstall);

            btnCancel = new Gtk.Button.with_label ("Cancel");
            btnCancel.set_hexpand (true);
            btnCancel.clicked.connect (() => response (Gtk.ResponseType.CANCEL));
            boxBottom.append (btnCancel);

            boxMain.append (boxBottom);

            boxMain.append (progressBarDownload);

            this.show ();
        }

        private void cbReleases_Changed () {
            currentRelease = (ProtonPlus.Models.CompatibilityTool.Release) cbReleases.GetCurrentObject ();
        }

        private void cbTools_Changed () {
            currentTool = (ProtonPlus.Models.CompatibilityTool) cbTools.GetCurrentObject ();
            entryDescription.set_text (currentTool.Description);
            cbReleases.GetChild ().set_model (ProtonPlus.Models.CompatibilityTool.GetReleasesModel (currentTool.GetReleases ()));
            cbReleases.GetChild ().set_active (0);
        }

        private void btnInstall_Clicked () {
            btnInstall.set_sensitive (false);
            progressBarDownload.set_show_text (true);
            Download ();
        }

        private void Download () {
            progressBarDownload.set_text ("Downloading...");
            new Thread<int> ("download", () => ProtonPlus.Manager.HTTP.Download (currentRelease.Download_URL, location.InstallDirectory + "/" + currentRelease.Label + ".tar.gz"));
            GLib.Timeout.add (75, () => {
                progressBarDownload.set_fraction (store.ProgressBar);
                if (store.ProgressBar == 1) {
                    Extract ();
                    return false;
                }
                return true;
            }, 1);
        }

        private void Extract () {
            progressBarDownload.set_text ("Extracting...");
            progressBarDownload.set_pulse_step (1);
            new Thread<void> ("extract", () => ProtonPlus.Manager.File.Extract (location.InstallDirectory + "/", currentRelease.Label + ".tar.gz"));
            GLib.Timeout.add (500, () => {
                progressBarDownload.pulse ();
                if (store.ProgressBarDone == true) {
                    progressBarDownload.set_text ("Done!");
                    progressBarDownload.set_fraction (store.ProgressBar = 0);
                    response (Gtk.ResponseType.APPLY);
                    return false;
                }
                return true;
            }, 1);
        }
    }
}

