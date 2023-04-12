namespace Windows.Tools {
    public class ReleaseInstaller : Gtk.Widget {
        Gtk.Button btnCancel;
        Gtk.Button btnGoBack;
        Gtk.ProgressBar progressBar;
        Gtk.TextBuffer textBuffer;
        bool cancelled;
        Thread<void> thread;
        string text;
        Models.Release release;
        Windows.Tools.LauncherInfo launcherInfo;

        public ReleaseInstaller (Windows.Tools.LauncherInfo launcherInfo) {
            //
            this.launcherInfo = launcherInfo;

            //
            var layout = new Gtk.BinLayout ();
            set_layout_manager (layout);

            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content.set_valign (Gtk.Align.CENTER);
            content.set_margin_bottom (15);
            content.set_margin_top (15);

            //
            progressBar = new Gtk.ProgressBar ();
            content.append (progressBar);

            //
            textBuffer = new Gtk.TextBuffer (new Gtk.TextTagTable ());

            //
            var textView = new Gtk.TextView ();
            textView.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
            textView.set_editable (false);
            textView.set_buffer (textBuffer);

            //
            var scrolledWindow = new Gtk.ScrolledWindow ();
            scrolledWindow.set_child (textView);
            scrolledWindow.set_min_content_height (200);
            content.append (scrolledWindow);

            //
            btnCancel = new Gtk.Button.with_label (_("Cancel"));
            btnCancel.clicked.connect (() => Cancel ());
            btnCancel.set_hexpand (true);
            content.append (btnCancel);

            //
            btnGoBack = new Gtk.Button.with_label (_("Go back"));
            btnGoBack.clicked.connect (GoBack);
            btnGoBack.set_hexpand (true);
            content.append (btnGoBack);

            //
            var clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);
            clamp.set_child (content);
            clamp.set_parent (this);
        }

        void GoBack () {
            launcherInfo.BtnBack.set_visible (true);
            launcherInfo.BtnBack.clicked ();
            btnGoBack.set_visible (false);
        }

        void Cancel (bool showCancelMessage = true, bool isEnd = false) {
            if (!cancelled) cancelled = true;
            if (showCancelMessage) textBuffer.set_text (text += _("Cancelled the install..."));
            if (!isEnd) release.InstallCancelled = true;
            progressBar.set_fraction (0);
            btnCancel.set_visible (false);
            btnGoBack.set_visible (true);
            ProtonPlus.get_instance ().mainWindow.State = Windows.Main.States.NORMAL;
        }

        public void Download (Models.Release release) {
            this.release = release;
            btnGoBack.set_visible (false);
            btnCancel.set_visible (true);

            ProtonPlus.get_instance ().mainWindow.State = Windows.Main.States.INSTALLING_TOOL;

            launcherInfo.BtnBack.set_visible (false);
            btnCancel.set_sensitive (!release.Tool.IsUsingGithubActions);
            if (release.Tool.IsUsingGithubActions) btnCancel.set_tooltip_text (_("You cannot cancel the operation for tools using Github Actions."));
            textBuffer.set_text (text = _("Download started...\n"));

            cancelled = false;
            bool done = false;
            bool requestError = false;
            bool downloadError = false;
            string errorMessage = "";
            double state = 0;

            thread = new Thread<void> ("download", () => {
                string url = release.DownloadURL;
                string path = release.Tool.Launcher.FullPath + "/" + release.Title + release.FileExtension;

                if (release.Tool.IsUsingGithubActions) {
                    Utils.Web.OldDownload (url, path, ref requestError, ref downloadError, ref errorMessage);
                } else {
                    Utils.Web.Download (url, path, ref state, ref cancelled, ref requestError, ref downloadError, ref errorMessage);
                }

                done = true;
            });

            int timeout_refresh = 75;
            if (release.Tool.IsUsingGithubActions) timeout_refresh = 500;

            GLib.Timeout.add (timeout_refresh, () => {
                if (requestError || downloadError) {
                    textBuffer.set_text (text += errorMessage);
                    Cancel (false);
                    return false;
                }

                if (cancelled) return false;

                if (release.Tool.IsUsingGithubActions) progressBar.pulse ();
                else progressBar.set_fraction (state);

                if (done) {
                    textBuffer.set_text (text += _("Download done...\n"));
                    Extract ();
                    return false;
                }

                return true;
            }, 1);
        }

        void Extract () {
            progressBar.set_pulse_step (1);
            textBuffer.set_text (text += _("Extraction started...\n"));

            btnCancel.set_sensitive (false);
            btnCancel.set_tooltip_text (_("You cannot cancel the operation while it's extracting."));

            bool done = false;
            bool error = false;

            thread = new Thread<void> ("extract", () => {
                string directory = release.Tool.Launcher.FullPath + "/";
                string sourcePath = Utils.File.Extract (directory, release.Title, release.FileExtension, ref cancelled);

                if (sourcePath == "") {
                    error = true;
                    return;
                }

                if (release.Tool.IsUsingGithubActions) {
                    sourcePath = Utils.File.Extract (directory, sourcePath.substring (0, sourcePath.length - 4).replace (directory, ""), ".tar", ref cancelled);
                }

                if (release.Tool.TitleType != Models.Tool.TitleTypes.NONE) {
                    string path = release.Tool.Launcher.FullPath + "/" + release.GetDirectoryName ();

                    Utils.File.Rename (sourcePath, path);
                }

                release.Tool.Launcher.install (release);

                done = true;
            });

            GLib.Timeout.add (500, () => {
                if (error) {
                    textBuffer.set_text (text += _("There was an error while extracting..."));
                    Cancel (false);
                    return false;
                }

                if (cancelled) return false;

                progressBar.pulse ();

                if (done) {
                    textBuffer.set_text (text += _("Extraction done...\n"));
                    textBuffer.set_text (text += release.Tool.Launcher.InstallMessage);
                    release.Installed = true;
                    release.SetSize ();
                    Cancel (false, true);

                    return false;
                }

                return true;
            }, 1);
        }
    }
}
