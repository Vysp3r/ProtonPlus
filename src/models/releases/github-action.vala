namespace ProtonPlus.Models.Releases {
    public class GitHubAction : Basic {
        public string artifacts_url { get; set; }

        public GitHubAction (Runners.Basic runner, string title, string release_date, string download_url, string page_url, string artifacts_url) {
            this.artifacts_url = artifacts_url;

            shared (runner, title, release_date, download_url, page_url);
        }

        internal override void refresh_interface_state (bool can_reset_processing = false) {
            row.set_title (@"$title ($release_date)");

            base.refresh_interface_state (can_reset_processing);
        }

        public override async bool install () {
            row.ui_state = Widgets.ReleaseRow.UIState.BUSY_INSTALLING;

            string path = runner.group.launcher.directory + runner.group.directory + "/" + title + ".zip";

            var download_valid = yield Utils.Web.Download (download_url, path, () => canceled, (is_percent, progress) => row.install_dialog.progress_text = is_percent? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress));

            if (!download_valid)
                return false;

            string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";

            string source_path = yield Utils.Filesystem.extract (directory, title, ".zip", () => canceled);

            if (source_path == "")
                return false;

            source_path = yield Utils.Filesystem.extract (directory, source_path.substring (0, source_path.length - 4).replace (directory, ""), ".tar", () => canceled);

            var runner = this.runner as Runners.Basic;

            yield Utils.Filesystem.rename (source_path, directory + runner.get_directory_name (title));

            runner.group.launcher.install (this);

            refresh_interface_state (true);

            return false;
        }
    }
}