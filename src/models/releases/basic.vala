namespace ProtonPlus.Models.Releases {
    public class Basic : Release<Parameters> {
        public string install_location { get; set; }
        public int64 download_size { get; set; }
        protected string destination_path { get; set; }

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

            var directory_name = ((Runners.Basic)runner).get_directory_name (title);
            var directory_name_valid = directory_name != "";
            var install_directory_valid = FileUtils.test (install_location, FileTest.IS_DIR);

            if (title.contains ("Latest") && Widgets.Application.window.updating) {
                var backup_directory_name = "%s Backup".printf (directory_name);
                var backup_directory_valid = FileUtils.test ("%s%s/%s".printf (runner.group.launcher.directory, runner.group.directory, backup_directory_name), FileTest.IS_DIR);

                state = (directory_name_valid && (install_directory_valid || backup_directory_valid)) ? State.UP_TO_DATE : State.NOT_INSTALLED;

                Widgets.Application.window.notify["updating"].connect(() => {
                    install_directory_valid = FileUtils.test (install_location, FileTest.IS_DIR);
                    backup_directory_valid = FileUtils.test ("%s%s/%s".printf (runner.group.launcher.directory, runner.group.directory, backup_directory_name), FileTest.IS_DIR);

                    if (!directory_name_valid || (backup_directory_valid && !install_directory_valid) || (!backup_directory_valid && !install_directory_valid))
                        state = State.NOT_INSTALLED;
                });
            } else {
                state = (directory_name_valid && install_directory_valid) ? State.UP_TO_DATE : State.NOT_INSTALLED;
            }
        }

        protected override async bool _start_install () {
            step = Step.DOWNLOADING;

            if (!download_url.contains (".tar"))
                return false;

            string download_path = "%s/%s.tar.gz".printf (Globals.DOWNLOAD_CACHE_PATH, title);

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

            string source_path = yield Utils.Filesystem.extract (extract_path, title, ".tar.gz", () => canceled);
            if (source_path == "")
                return false;

            step = Step.MOVING;

            var runner = this.runner as Runners.Basic;

            destination_path = "%s%s/%s/".printf (runner.group.launcher.directory, runner.group.directory, runner.get_directory_name (title)) ;

            var renaming_valid = yield Utils.Filesystem.move_directory (source_path, destination_path);
            if (!renaming_valid)
                return false;

            add_to_games_tab ();

            return true;
        }

        protected override async bool _start_remove (Parameters parameters) {
            step = Step.REMOVING;

            var deleted = yield Utils.Filesystem.delete_directory (install_location);

            if (!deleted)
                return false;

            remove_from_games_tab ();

            return true;
        }

        internal void add_to_games_tab () {
            var simple_runner = new SimpleRunner.from_path(install_location);

            runner.group.launcher.compatibility_tools.add (simple_runner);
        }

        internal void remove_from_games_tab () {
            foreach (var simple_runner in runner.group.launcher.compatibility_tools) {
                if (simple_runner.path == install_location) {
                    runner.group.launcher.compatibility_tools.remove (simple_runner);
                    break;
                }
            }
        }
    }
}