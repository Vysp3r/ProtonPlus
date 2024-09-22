namespace ProtonPlus.Models.Releases {
    public class GitHubAction : Basic {
        public string artifacts_url { get; set; }

        public GitHubAction (Runners.Basic runner, string title, string release_date, string download_url, string page_url, string artifacts_url) {
            this.artifacts_url = artifacts_url;

            shared (runner, title, release_date, download_url, page_url);

            displayed_title = @"$title ($release_date)";
        }

        protected override async bool _start_install () {
            send_message (_("Downloading..."));

            string path = runner.group.launcher.directory + runner.group.directory + "/" + title + ".tar.gz";

            var download_valid = yield Utils.Web.Download (download_url, path, () => canceled, (is_percent, progress) => this.progress = is_percent? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress));

            if (!download_valid)
                return false;

            send_message (_("Extracting..."));

            string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";

            string source_path = yield Utils.Filesystem.extract (directory, title, ".tar.gz", () => canceled);

            if (source_path == "")
                return false;

            source_path = yield Utils.Filesystem.extract (directory, source_path.substring (0, source_path.length - 4).replace (directory, ""), ".tar", () => canceled);

            if (source_path == "")
                return false;

            send_message (_("Renaming..."));

            var runner = this.runner as Runners.Basic;

            var renaming_valid = yield Utils.Filesystem.rename (source_path, directory + runner.get_directory_name (title));

            if (!renaming_valid)
                return false;

            send_message (_("Running installation script..."));

            var install_script_success = runner.group.launcher.install (this);

            if (!install_script_success)
                return false;

            return true;
        }
    }
}