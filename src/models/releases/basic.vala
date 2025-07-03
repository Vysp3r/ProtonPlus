namespace ProtonPlus.Models.Releases {
    public class Basic : Release<Parameters> {
        public string install_location { get; set; }
        public int64 download_size { get; set; }

        public Basic.simple (Runners.Basic runner, string title, string install_location) {
            this.runner = runner;
            this.title = title;
            this.install_location = install_location;
        }

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
            this.displayed_title = title;
            this.description = description;
            this.release_date = release_date;
            this.download_url = download_url;
            this.page_url = page_url;

            install_location = runner.group.launcher.directory + runner.group.directory + "/" + runner.get_directory_name (title);

            refresh_state ();
        }

        protected override void refresh_state () {
            canceled = false;

            step = Step.NOTHING;

            state = (((Runners.Basic)runner).get_directory_name (title) != "" && FileUtils.test (install_location, FileTest.IS_DIR)) ? State.UP_TO_DATE : State.NOT_INSTALLED;
        }

        protected override async bool _start_install () {
            step = Step.DOWNLOADING;

            string path = runner.group.launcher.directory + runner.group.directory + "/" + title + ".tar.gz";

            var download_valid = yield Utils.Web.Download (download_url, path, () => canceled, (is_percent, progress) => this.progress = is_percent? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress));

            if (!download_valid)
                return false;

            step = Step.EXTRACTING;

            string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";

            string source_path = yield Utils.Filesystem.extract (directory, title, ".tar.gz", () => canceled);

            if (source_path == "")
                return false;

            step = Step.RENAMING;

            var runner = this.runner as Runners.Basic;

            var renaming_valid = yield Utils.Filesystem.rename (source_path, directory + runner.get_directory_name (title));

            if (!renaming_valid)
                return false;

            step = Step.POST_INSTALL_SCRIPT;

            var install_script_success = runner.group.launcher.install (this);

            if (!install_script_success)
                return false;

            return true;
        }

        protected override async bool _start_remove (Parameters parameters) {
            step = Step.REMOVING;

            var deleted = yield Utils.Filesystem.delete_directory (install_location);

            if (!deleted)
                return false;

            step = Step.POST_REMOVAL_SCRIPT;

            var uninstall_script_success = runner.group.launcher.uninstall (this);

            if (!uninstall_script_success)
                return false;

            return true;
        }
    }
}