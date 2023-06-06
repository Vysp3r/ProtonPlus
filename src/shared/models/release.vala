

namespace ProtonPlus.Shared.Models {
    public class Release {
        public Models.Runner runner;
        public string title;
        public string download_link;
        public string checksum_link;
        public string info_link;
        public string release_date;
        public int64 download_size;
        public string file_extension;
        public bool installed;
        public string directory;
        public int64 size;
        public bool installation_cancelled;
        public int installation_progress;
        public bool installation_error;
        public bool installation_api_error;

        public Release (Runner runner, string title, string download_url, string info_link, string release_date, string checksum_url, int64 download_size, string file_extension) {
            this.runner = runner;
            this.title = title;
            this.download_link = download_url;
            this.info_link = info_link;
            this.file_extension = file_extension;
            this.release_date = release_date;
            this.download_size = download_size;
            this.checksum_link = checksum_url;
            this.directory = runner.group.launcher.directory + runner.group.directory + "/" + get_directory_name ();
            this.installed = FileUtils.test (directory, FileTest.IS_DIR);
            this.size = 0;

            // message (title + "| " + directory);

            set_size ();
        }

        public void set_size () {
            if (installed) size = (int64) Utils.Filesystem.GetDirectorySize (directory);
        }

        public string get_formatted_download_size () {
            if (download_size < 0) return "Not available";
            return Utils.Filesystem.ConvertBytesToString (download_size);
        }

        public string get_formatted_size () {
            return Utils.Filesystem.ConvertBytesToString (size);
        }

        public string get_directory_name () {
            switch (runner.title_type) {
            case Runner.title_types.WINE_LUTRIS_BOTTLES:
                if (title.contains ("LoL")) {
                    var parts = title.split ("-");
                    return "lutris-ge-lol-" + parts[0] + "-" + parts[2];
                }
                return title.down ().replace ("-wine", "");
            case Runner.title_types.WINE_GE_BOTTLES:
                return "wine-" + title.down ();
            case Runner.title_types.BOTTLES:
                return title.down ().replace (" ", "-");
            case Runner.title_types.PROTON_HGL:
                return @"Proton-$title";
            case Runner.title_types.WINE_HGL:
                return @"Wine-$title";
            case Runner.title_types.TOOL_NAME:
                return runner.title + @" $title";
            case Runner.title_types.PROTON_TKG:
                return @"Proton-Tkg-$title";
            case Runner.title_types.LUTRIS_DXVK:
                return @"dxvk-" + title.replace ("v", "");
            case Runner.title_types.LUTRIS_DXVK_ASYNC_SPORIF:
                return @"dxvk-async-$title";
            case Runner.title_types.LUTRIS_DXVK_ASYNC_GNUSENPAI:
                return @"dxvk-sc-async-" + title.replace ("v", "").replace ("-sc-async", "");
            case Runner.title_types.LUTRIS_WINE_GE:
                if (title.contains ("LoL")) {
                    var parts = title.split ("-");
                    return "lutris-ge-lol-" + parts[0] + "-" + parts[2] + "-x86_64";
                }
                return @"lutris-$title-x86_64";
            case Runner.title_types.LUTRIS_WINE:
                return title.replace ("-wine", "") + "-x86_64";
            case Runner.title_types.LUTRIS_KRON4EK_VANILLA:
                return @"wine-$title-amd64";
            case Runner.title_types.LUTRIS_KRON4EK_TKG:
                return @"wine-$title-staging-tkg-amd64";
            default:
                return title;
            }
        }

        public void delete (bool wait_for_thread = false) {
            var thread = new Thread<void> ("deleteThread", () => {
                Utils.Filesystem.DeleteDirectory (directory);
                runner.group.launcher.uninstall (this);
                installed = false;
            });
            if (wait_for_thread) thread.join ();
        }

        public void install () {
            installation_progress = 0;
            installation_error = false;
            installation_api_error = false;
            installation_cancelled = false;

            new Thread<void> ("download", () => {
                string url = download_link;
                string path = runner.group.launcher.directory + "/" + runner.group.directory + "/" + title + file_extension;

                if (runner.is_using_github_actions) {
                    Utils.Web.OldDownload (url, path, ref installation_api_error, ref installation_error);
                } else {
                    Utils.Web.Download (url, path, ref installation_progress, ref installation_cancelled, ref installation_api_error, ref installation_error);
                }

                if (installation_error || installation_api_error || installation_cancelled) {
                    // Cancel (false);
                    return;
                }

                extract ();
            });
        }

        void extract () {
            new Thread<void> ("extract", () => {
                string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";
                string sourcePath = Utils.Filesystem.Extract (directory, title, file_extension, ref installation_cancelled);

                if (sourcePath == "") {
                    installation_error = true;
                    return;
                }

                if (runner.is_using_github_actions) {
                    // message (sourcePath.substring (0, sourcePath.length - 4).replace (directory, ""));
                    sourcePath = Utils.Filesystem.Extract (directory, sourcePath.substring (0, sourcePath.length - 4).replace (directory, ""), ".tar", ref installation_cancelled);
                }

                if (installation_error || installation_cancelled) {
                    // Cancel (false);
                    return;
                }

                if (runner.title_type != Runner.title_types.NONE) {
                    string path = directory + get_directory_name ();

                    Utils.Filesystem.Rename (sourcePath, path);
                }

                runner.group.launcher.install (this);

                installed = true;
                set_size ();
            });
        }
    }
}