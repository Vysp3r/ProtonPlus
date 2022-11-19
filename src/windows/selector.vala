namespace ProtonPlus.Windows {
    public class Selector : Gtk.Dialog {
        //Widgets
        Gtk.Button btnInstall;
        Adw.ComboRow crTools;
        Adw.ComboRow crReleases;
        Gtk.ProgressBar progressBarDownload;

        //Values
        ProtonPlus.Models.Location location;
        ProtonPlus.Models.Tool currentTool;
        ProtonPlus.Models.Release currentRelease;
        Thread<int> downloadThread;
        Thread<void> extractThread;

        //Stores
        ProtonPlus.Stores.Threads store;

        public Selector (Gtk.ApplicationWindow parent, ProtonPlus.Models.Location location) {
            this.set_transient_for (parent);
            this.set_title("Install Compatibility Tool");
            this.set_default_size (330, 0);

            this.location = location;

            store = ProtonPlus.Stores.Threads.instance ();

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
            crTools.set_model (ProtonPlus.Models.Tool.GetStore (location.Tools));
            crTools.set_factory (factoryTools);
            crTools.notify.connect (crTools_Notify);

            var groupTools = new Adw.PreferencesGroup ();
            groupTools.add (crTools);
            boxMain.append (groupTools);

            crTools.notify_property ("selected");

            var factoryReleases = new Gtk.SignalListItemFactory ();
            factoryReleases.setup.connect (factoryReleases_Setup);
            factoryReleases.bind.connect (factoryReleases_Bind);

            crReleases = new Adw.ComboRow ();
            crReleases.set_title ("Version");
            crReleases.set_model (ProtonPlus.Models.Release.GetStore (ProtonPlus.Models.Release.GetReleases (currentTool.Endpoint,currentTool.AssetPosition)));
            crReleases.set_factory (factoryReleases);
            crReleases.notify.connect (crReleases_Notify);

            var groupReleases = new Adw.PreferencesGroup ();
            groupReleases.add (crReleases);
            boxMain.append (groupReleases);

            crReleases.notify_property ("selected");

            var boxBottom = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            boxBottom.set_hexpand (true);

            progressBarDownload = new Gtk.ProgressBar ();
            progressBarDownload.set_visible (false);
            boxMain.append (progressBarDownload);

            var btnInfo = new Gtk.Button.with_label ("Info");
            btnInfo.add_css_class ("pill");
            btnInfo.set_hexpand (true);
            btnInfo.clicked.connect (() => Gtk.show_uri (this, currentRelease.Page_URL, Gdk.CURRENT_TIME));
            boxBottom.append (btnInfo);

            btnInstall = new Gtk.Button.with_label ("Install");
            btnInstall.add_css_class ("pill");
            btnInstall.set_hexpand (true);
            btnInstall.clicked.connect (btnInstall_Clicked);
            boxBottom.append (btnInstall);

            var btnCancel = new Gtk.Button.with_label ("Cancel");
            btnCancel.add_css_class ("pill");
            btnCancel.set_hexpand (true);
            btnCancel.clicked.connect (() => response (Gtk.ResponseType.CANCEL));
            boxBottom.append (btnCancel);

            boxMain.append (boxBottom);

            this.show ();
        }

        private void btnInstall_Clicked () {
            btnInstall.set_sensitive (false);
            progressBarDownload.set_visible (true);
            progressBarDownload.set_show_text (true);
            Download ();
        }

        private void Download () {
            progressBarDownload.set_text ("Downloading...");
            downloadThread = new Thread<int> ("download", () => ProtonPlus.Manager.HTTP.Download (currentRelease.Download_URL, location.InstallDirectory + "/" + currentRelease.Label + ".tar.gz"));
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
            extractThread = new Thread<void> ("extract", () => ProtonPlus.Manager.File.Extract (location.InstallDirectory + "/", currentTool.Title, currentRelease.Label));
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

        public void crTools_Notify (GLib.ParamSpec param) {
            if(param.get_name () == "selected"){
                currentTool = (ProtonPlus.Models.Tool) crTools.get_selected_item ();
                crReleases.set_model (ProtonPlus.Models.Release.GetStore (ProtonPlus.Models.Release.GetReleases (currentTool.Endpoint,currentTool.AssetPosition)));
            }
        }

        void factoryTools_Bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var string_holder = list_item.get_item () as ProtonPlus.Models.Tool;

            var title = list_item.get_data<Gtk.Label>("title");
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

        public void crReleases_Notify (GLib.ParamSpec param) {
            if(param.get_name () == "selected"){
                currentRelease = (ProtonPlus.Models.Release) crReleases.get_selected_item ();
            }
        }

        void factoryReleases_Bind (Gtk.SignalListItemFactory factory, Gtk.ListItem list_item) {
            var string_holder = list_item.get_item () as ProtonPlus.Models.Release;

            var title = list_item.get_data<Gtk.Label>("title");
            title.label = string_holder.Label;
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

