namespace ProtonPlus.Models.Releases {
    public class Basic : Release {
        public string install_location { get; set; }
        public int64 download_size { get; set; }
        public string artifacts_url { get; set; }

        public Basic.github (Runners.Basic runner, string title, string description, string release_date, int64 download_size, string download_url, string page_url) {
            this.description = description;
            this.download_size = download_size;

            shared (runner, title, release_date, download_url, page_url);
        }

        public Basic.github_action (Runners.Basic runner, string title, string release_date, string download_url, string page_url, string artifacts_url) {
            this.artifacts_url = artifacts_url;

            shared (runner, title, release_date, download_url, page_url);
        }

        public Basic.gitlab (Runners.Basic runner, string title, string description, string release_date, string download_url, string page_url) {
            this.description = description;

            shared (runner, title, release_date, download_url, page_url);
        }

        void shared (Runners.Basic runner, string title, string release_date, string download_url, string page_url) {
            this.runner = runner;
            this.title = title;
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

        public async bool install () {
            return false;
        }

        public async bool remove () {
            return false;
        }
    }
}