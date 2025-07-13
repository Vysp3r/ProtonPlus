namespace ProtonPlus.Models.Releases {
    public class GitHubAction : Basic {
        public string artifacts_url { get; set; }

        public GitHubAction (Runners.Basic runner, string title, string release_date, string download_url, string page_url, string artifacts_url) {
            this.artifacts_url = artifacts_url;

            shared (runner, title, release_date, download_url, page_url);

            displayed_title = @"$title ($release_date)";
        }

        protected override async bool _start_install () {
            step = Step.DOWNLOADING;

            string download_path = "%s/%s.tar.gz".printf (Globals.DOWNLOAD_CACHE_PATH, title);

            var download_valid = yield Utils.Web.Download (download_url, download_path, () => canceled, (is_percent, progress) => this.progress = is_percent? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress));

            if (!download_valid)
                return false;

            step = Step.EXTRACTING;

            string extract_path = "%s/".printf (Globals.DOWNLOAD_CACHE_PATH);

            string source_path = yield Utils.Filesystem.extract (extract_path, title, ".tar.gz", () => canceled);

            if (source_path == "")
                return false;

            source_path = yield Utils.Filesystem.extract (extract_path, source_path.substring (0, source_path.length - 4).replace (extract_path, ""), ".tar", () => canceled);

            if (source_path == "")
                return false;

            step = Step.RENAMING;

            var runner = this.runner as Runners.Basic;

            destination_path = "%s%s/%s/".printf (runner.group.launcher.directory, runner.group.directory, runner.get_directory_name (title)) ;

            var renaming_valid = yield Utils.Filesystem.move_directory (source_path, destination_path);

            if (!renaming_valid)
                return false;

            step = Step.POST_INSTALL_SCRIPT;

            var install_script_success = runner.group.launcher.install (this);

            if (!install_script_success)
                return false;

            return true;
        }
    }
}