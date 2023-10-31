namespace ProtonPlus.Models {
    public class Release : Object {
        public Runner runner { get; set; }
        public string title { get; set; }
        public string download_link { get; set; }
        public string checksum_link { get; set; }
        public string info_link { get; set; }
        public string release_date { get; set; }
        public int64 download_size { get; set; }
        public string file_extension { get; set; }
        public bool installed { get; set; }
        public string directory { get; set; }
        public int64 directory_size { get; set; }

        public int installation_progress;

        public STATUS previous_status;
        STATUS _status;
        public STATUS status { 
            get {
                return _status;
            } private set {
                previous_status = _status;
                _status = value;
            } 
        }
        public enum STATUS {
            INSTALLED,
            UNINSTALLED,
            INSTALLING,
            UNINSTALLING,
            CANCELLED
        }

        public ERRORS error { get; private set; }
        public enum ERRORS {
            NONE,
            API,
            EXTRACT,
            UNEXPECTED
        }

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
            this.directory_size = 0; // this.directory_size = (int64) Utils.Filesystem.GetDirectorySize (directory); Disabled since Utils.Filesystem.GetDirectorySize is buggy and we don't have a way to see that data anyway
        }

        public string get_formatted_download_size () {
            if (download_size < 0) return "Not available";
            return Utils.Filesystem.ConvertBytesToString (download_size);
        }

        public string get_formatted_size () {
            return Utils.Filesystem.ConvertBytesToString (directory_size);
        }

        public string get_directory_name () {
            switch (runner.title_type) {
            case Runner.title_types.TOOL_NAME:
                return runner.title + @" $title";
            case Runner.title_types.PROTON_TKG:
                return @"Proton-Tkg-$title";
            case Runner.title_types.KRON4EK_VANILLA:
                return @"wine-$title-amd64";
            case Runner.title_types.KRON4EK_STAGING:
                return @"wine-$title-staging-amd64";
            case Runner.title_types.KRON4EK_STAGING_TKG:
                return @"wine-$title-staging-tkg-amd64";
            case Runner.title_types.DXVK:
                return title.replace ("v", "dxvk-");
            case Runner.title_types.DXVK_ASYNC_SPORIF:
                return @"dxvk-async-$title";
            case Runner.title_types.STEAM_PROTON_GE:
                if (title.contains (".")) {
                    return "Proton-" + title;
                }
                return title;
            case Runner.title_types.LUTRIS_DXVK_ASYNC_GNUSENPAI:
                return @"dxvk-sc-async-" + title.replace ("v", "").replace ("-sc-async", "");
            case Runner.title_types.LUTRIS_DXVK_GPLASYNC:
                return @"dxvk-gplasync-" + title;
            case Runner.title_types.LUTRIS_WINE_GE:
                if (title.contains ("LOL")) {
                    return @"lutris-$title-x86_64".down ();
                }
                if (title.contains ("LoL")) {
                    var parts = title.split ("-");
                    return "lutris-ge-lol-" + parts[0] + "-" + parts[2] + "-x86_64";
                }
                return @"lutris-$title-x86_64";
            case Runner.title_types.LUTRIS_WINE:
                return title.replace ("-wine", "") + "-x86_64";
            case Runner.title_types.LUTRIS_VKD3D_PROTON:
                return title.replace ("v", "vkd3d-proton-");
            case Runner.title_types.HGL_PROTON_GE:
                return @"Proton-$title";
            case Runner.title_types.HGL_WINE_GE:
                return @"Wine-$title";
            case Runner.title_types.HGL_VKD3D:
                return title.replace ("v", "vkd3d-lutris-");
            case Runner.title_types.BOTTLES:
                return title.down ().replace (" ", "-");
            case Runner.title_types.BOTTLES_PROTON_GE:
                return title.down ();
            case Runner.title_types.BOTTLES_WINE_GE:
                return "wine-" + title.down ();
            case Runner.title_types.BOTTLES_WINE_LUTRIS:
                if (title.contains ("LoL")) {
                    var parts = title.split ("-");
                    return "lutris-ge-lol-" + parts[0] + "-" + parts[2];
                }
                if (title.contains ("LOL")) {
                    return "lutris-" + title.down ();
                }
                return title.down ().replace ("-wine", "");
            default:
                return title;
            }
        }

        public static string get_directory_name_reverse (Runner runner, string title) {
            switch (runner.title_type) {
            case Runner.title_types.TOOL_NAME:
                return title.replace (runner.title + " ", "");
            case Runner.title_types.PROTON_TKG:
                return title.replace ("Proton-Tkg-", "");
            case Runner.title_types.KRON4EK_VANILLA:
                if (title.contains ("staging")) {
                    return "";
                }
                return title.replace ("wine-", "").replace ("-amd64", "");
            case Runner.title_types.KRON4EK_STAGING:
                return title.replace ("wine-", "").replace ("-staging-amd64", "");
            case Runner.title_types.KRON4EK_STAGING_TKG:
                return title.replace ("wine-", "").replace ("-staging-tkg-amd64", "");
            case Runner.title_types.DXVK:
                if (title.contains ("async")) {
                    return "";
                }
                return title.replace ("dxvk-", "v");
            case Runner.title_types.DXVK_ASYNC_SPORIF:
                if (!title.contains ("async")) {
                    return "";
                }
                return title.replace ("dxvk-async-", "");
            case Runner.title_types.STEAM_PROTON_GE:
                if (title.contains ("Tkg")) {
                    return "";
                }
                return title.replace ("Proton-", "");
            case Runner.title_types.LUTRIS_DXVK_ASYNC_GNUSENPAI:
                return "v" + title.replace ("dxvk-sc-async-", "") + "-sc-async";
            case Runner.title_types.LUTRIS_DXVK_GPLASYNC:
                return title.replace ("dxvk-gplasync-", "");
            case Runner.title_types.LUTRIS_WINE_GE:
                if (!title.contains ("GE-Proton") && !title.contains ("lol")) {
                    return "";
                }
                if (title.contains ("lol") && title.contains ("p")) {
                    return title.replace ("lutris-ge-lol-", "GE-LOL-").replace ("-x86_64", "");
                }
                if (title.contains ("lol")) {
                    return title.replace ("lutris-ge-lol-", "").replace ("-x86_64", "").replace ("-", "-GE-") + "-LoL";
                }
                return title.replace ("lutris-", "").replace ("-x86_64", "");
            case Runner.title_types.LUTRIS_WINE:
                if (title.contains ("Proton") || title.contains ("ge-lol")) {
                    return "";
                }
                return title.replace ("lutris", "lutris-wine").replace ("-x86_64", "");
            case Runner.title_types.LUTRIS_VKD3D:
                if (title.contains ("vkd3d")) {
                    return "";
                }
                return title;
            case Runner.title_types.LUTRIS_VKD3D_PROTON:
                return title.replace ("vkd3d-proton-", "");
            case Runner.title_types.HGL_PROTON_GE:
                if (title.contains ("Tkg")) {
                    return "";
                }
                return title.replace ("Proton-", "");
            case Runner.title_types.HGL_WINE_GE:
                return title.replace ("Wine-", "");
            case Runner.title_types.HGL_VKD3D:
                return title.replace ("vkd3d-lutris-", "v");
            case Runner.title_types.BOTTLES:
                if (title.contains ("soda")) {
                    var parts = title.split ("-");
                    var start = parts[0].substring (1);
                    return parts[0][0].to_string ().up () + start + " " + parts[1] + "-" + parts[2];
                }
                var parts = title.split ("-");
                var start = parts[0].substring (1);
                return parts[0][0].to_string ().up () + start + " " + parts[1];
            case Runner.title_types.BOTTLES_PROTON_GE:
                if (!title.contains ("ge-proton") || title.contains ("wine")) {
                    return "";
                }
                return title.replace ("ge-proton", "GE-Proton");
            case Runner.title_types.BOTTLES_WINE_GE:
                return title.replace ("wine-ge-proton", "GE-Proton");
            case Runner.title_types.BOTTLES_WINE_LUTRIS:
                if (!title.contains ("lutris-ge-lol-p")) {
                    return title.replace ("lutris-ge-lol-", "").replace ("-", "-GE-") + "-LoL";
                }
                return title.replace ("lutris-ge-lol-p", "GE-LOL-p");
            default:
                return title;
            }
        }

        public void delete (bool wait_for_thread = false) {
            status = STATUS.UNINSTALLING;
            var thread = new Thread<void> ("deleteThread", () => {
                Utils.Filesystem.DeleteDirectory (directory);
                runner.group.launcher.uninstall (this);
                status = STATUS.UNINSTALLED;
            });
            if (wait_for_thread) thread.join ();
        }

        public void install () {
            status = STATUS.INSTALLING;
            error = ERRORS.NONE;
            installation_progress = 0;

            new Thread<void> ("download", () => {
                string url = download_link;
                string path = runner.group.launcher.directory + "/" + runner.group.directory + "/" + title + file_extension;

                if (runner.is_using_github_actions) {
                    switch(Utils.Web.OldDownload (url, path)) {
                        case Utils.Web.DOWNLOAD_CODES.API_ERROR:
                            error = ERRORS.API;
                            break;
                        case Utils.Web.DOWNLOAD_CODES.UNEXPECTED_ERROR:
                            error = ERRORS.UNEXPECTED;
                            break;
                        case Utils.Web.DOWNLOAD_CODES.SUCCESS:
                            error = ERRORS.NONE;
                            break;
                    }
                } else {
                    var result = Utils.Web.Download (url, path, () => status == STATUS.CANCELLED, ref installation_progress);
                    switch(result) {
                        case Utils.Web.DOWNLOAD_CODES.API_ERROR:
                            error = ERRORS.API;
                            break;
                        case Utils.Web.DOWNLOAD_CODES.UNEXPECTED_ERROR:
                            error = ERRORS.UNEXPECTED;
                            break;
                        case Utils.Web.DOWNLOAD_CODES.SUCCESS:
                            error = ERRORS.NONE;
                            break;
                    }
                }

                if (error != ERRORS.NONE || status == STATUS.CANCELLED) {
                    status = STATUS.UNINSTALLED;
                    return;
                }

                extract ();
            });
        }

        void extract () {
            new Thread<void> ("extract", () => {
                string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";
                string sourcePath = Utils.Filesystem.Extract (directory, title, file_extension, () => status == STATUS.CANCELLED);

                if (sourcePath == "") {
                    error = ERRORS.EXTRACT;
                    status = STATUS.UNINSTALLED;
                    return;
                }

                if (runner.is_using_github_actions) {
                    sourcePath = Utils.Filesystem.Extract (directory, sourcePath.substring (0, sourcePath.length - 4).replace (directory, ""), ".tar", () => status == STATUS.CANCELLED);
                }

                if (error != ERRORS.NONE || status == STATUS.CANCELLED) {
                    status = STATUS.UNINSTALLED;
                    return;
                }

                if (runner.title_type != Runner.title_types.NONE) {
                    string path = directory + get_directory_name ();

                    Utils.Filesystem.Rename (sourcePath, path);
                }

                runner.group.launcher.install (this);

                status = STATUS.INSTALLED;

                // directory_size = (int64) Utils.Filesystem.GetDirectorySize (directory);
            });
        }

        public void cancel() {
            status = Models.Release.STATUS.CANCELLED;
        }
    }
}