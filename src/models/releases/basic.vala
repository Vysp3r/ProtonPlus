namespace ProtonPlus.Models.Releases {
    public class Basic : Release {
        public string install_location { get; set; }
        public int64 download_size { get; set; }

        public Basic.github (Runners.Basic runner, string title, string description, string release_date, int64 download_size, string download_url, string page_url) {
            this.description = description;
            this.download_size = download_size;

            shared (runner, title, release_date, download_url, page_url);
        }

        public Basic.gitlab (Runners.Basic runner, string title, string description, string release_date, string download_url, string page_url) {
            this.description = description;

            shared (runner, title, release_date, download_url, page_url);
        }

        internal void shared (Runners.Basic runner, string title, string release_date, string download_url, string page_url) {
            this.runner = runner;
            this.title = title;
            this.description = description;
            this.release_date = release_date;
            this.download_url = download_url;
            this.page_url = page_url;

            install_location = runner.group.launcher.directory + runner.group.directory + "/" + runner.get_directory_name (title);

            var row = new Widgets.ReleaseRows.Basic ();
            row.initialize (this);

            this.row = row;

            refresh_interface_state ();
        }

        internal override void refresh_interface_state (bool can_reset_processing = false) {
            installed = FileUtils.test (install_location, FileTest.IS_DIR);

            var change_state = (can_reset_processing
                                || (row.ui_state != Widgets.ReleaseRow.UIState.BUSY_INSTALLING
                                    && row.ui_state != Widgets.ReleaseRow.UIState.BUSY_REMOVING));
            if (change_state)
                row.ui_state = installed ? Widgets.ReleaseRow.UIState.INSTALLED : Widgets.ReleaseRow.UIState.NOT_INSTALLED;
        }

        public virtual async bool install () {
            row.ui_state = Widgets.ReleaseRow.UIState.BUSY_INSTALLING;

            string path = runner.group.launcher.directory + runner.group.directory + "/" + title + ".tar.gz";

            var download_valid = yield Utils.Web.Download (download_url, path, () => canceled, (is_percent, progress) => row.install_dialog.progress_text = is_percent? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress));

            if (!download_valid)
                return false;

            string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";

            string source_path = yield Utils.Filesystem.extract (directory, title, ".tar.gz", () => canceled);

            if (source_path == "")
                return false;

            var runner = this.runner as Runners.Basic;

            yield Utils.Filesystem.rename (source_path, directory + runner.get_directory_name (title));

            runner.group.launcher.install (this);

            refresh_interface_state (true);

            return true;
        }

        public virtual async bool remove () {
            row.ui_state = Widgets.ReleaseRow.UIState.BUSY_REMOVING;

            var deleted = yield Utils.Filesystem.delete_directory (install_location);

            if (deleted) {
                runner.group.launcher.uninstall (this);
            }

            refresh_interface_state (true);

            return deleted;
        }
    }
}