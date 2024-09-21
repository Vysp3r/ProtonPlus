namespace ProtonPlus.Models.Releases {
    public class GitHubAction : Basic {
        public string artifacts_url { get; set; }

        public GitHubAction (Runners.Basic runner, string title, string release_date, string download_url, string page_url, string artifacts_url) {
            this.artifacts_url = artifacts_url;

            row.set_title (@"$title ($release_date)");

            shared (runner, title, release_date, download_url, page_url);
        }

        public override async bool install () {
            send_message (_("The installation of %s has begun.").printf (title));

            send_message (_("Downloading..."));

            string path = runner.group.launcher.directory + runner.group.directory + "/" + title + ".zip";

            var download_valid = yield Utils.Web.Download (download_url, path, () => canceled, (is_percent, progress) => row.install_dialog.progress_text = is_percent? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress));

            if (!download_valid) {
                install_error ();
                return false;
            }

            send_message (_("Extracting..."));

            string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";

            string source_path = yield Utils.Filesystem.extract (directory, title, ".zip", () => canceled);

            if (source_path == "") {
                install_error ();
                return false;
            }

            source_path = yield Utils.Filesystem.extract (directory, source_path.substring (0, source_path.length - 4).replace (directory, ""), ".tar", () => canceled);

            send_message (_("Renaming..."));

            var runner = this.runner as Runners.Basic;

            yield Utils.Filesystem.rename (source_path, directory + runner.get_directory_name (title));

            send_message (_("Running post installation script..."));

            runner.group.launcher.install (this);

            send_message (_("The installation of %s is complete.").printf (title));

            installed = true;

            return false;
        }
    }
}