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

            if (!download_url.contains (".zip"))
                return false;

            string download_path = "%s/%s.zip".printf (Globals.DOWNLOAD_CACHE_PATH, title);

            if (!FileUtils.test (download_path, FileTest.EXISTS)) {
                var download_valid = yield Utils.Web.Download (download_url, download_path, () => canceled, (is_percent, progress, speed_kbps, seconds_remaining) => {
                    this.progress = is_percent ? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress);
                    this.speed_kbps = speed_kbps;
                    this.seconds_remaining = seconds_remaining;
                });

                if (!download_valid)
                    return false;
            }
            
            step = Step.EXTRACTING;

            string extract_path = "%s/".printf (Globals.DOWNLOAD_CACHE_PATH);

            string source_path = yield Utils.Filesystem.extract (extract_path, title, ".zip", () => canceled);

            if (source_path == "")
                return false;

            source_path = yield Utils.Filesystem.extract (extract_path, source_path.substring (0, source_path.length - 4).replace (extract_path, ""), ".tar", () => canceled);

            if (source_path == "")
                return false;

            step = Step.MOVING;

            var runner = this.runner as Runners.Basic;

            destination_path = "%s%s/%s/".printf (runner.group.launcher.directory, runner.group.directory, runner.get_directory_name (title)) ;

            var renaming_valid = yield Utils.Filesystem.move_directory (source_path, destination_path);

            if (!renaming_valid)
                return false;

            return true;
        }
    }
}
