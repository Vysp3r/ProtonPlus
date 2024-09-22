namespace ProtonPlus.Models.Releases {
    public class Basic : Release {
        public string install_location { get; set; }
        public int64 download_size { get; set; }
        public State state { get; set; }

        public enum State {
            NOT_INSTALLED,
            INSTALLED,
            BUSY_INSTALLING,
            BUSY_REMOVING,
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
        }

        protected void refresh_state () {
            state = FileUtils.test (install_location, FileTest.IS_DIR) ? State.INSTALLED : State.NOT_INSTALLED;
        }

        public async bool install () {
            state = State.BUSY_INSTALLING;

            send_message (_("The installation of %s has begun.").printf (title));

            var install_success = yield start_install ();

            if (canceled)
                send_message (_("The installation of %s was canceled.").printf (title));
            else if (install_success)
                send_message (_("The installation of %s is complete.").printf (title));
            else
                send_message (_("An unexpected error occurred while installing %s.").printf (title));

            if (canceled || !install_success)
                yield start_remove ();

            refresh_state ();

            return true;
        }

        protected virtual async bool start_install () {
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

        public async bool remove () {
            state = State.BUSY_REMOVING;

            send_message (_("The removal of %s has begun.").printf (title));

            var remove_success = yield start_remove ();

            if (remove_success)
                send_message (_("The removal of %s is complete.").printf (title));
            else
                send_message (_("An unexpected error occurred while removing %s.").printf (title));

            refresh_state ();

            return true;
        }

        protected virtual async bool start_remove () {
            send_message (_("Deleting..."));

            var deleted = yield Utils.Filesystem.delete_directory (install_location);

            if (!deleted)
                return false;

            send_message (_("Running removal script..."));

            var uninstall_script_success = runner.group.launcher.uninstall (this);

            if (!uninstall_script_success)
                return false;

            return true;
        }
    }
}