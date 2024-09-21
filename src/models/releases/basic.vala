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

            installed = FileUtils.test (install_location, FileTest.IS_DIR);
        }

        public virtual async bool install () {
            send_message (_("The installation of %s has begun.").printf (title));

            send_message (_("Downloading..."));

            string path = runner.group.launcher.directory + runner.group.directory + "/" + title + ".tar.gz";

            var download_valid = yield Utils.Web.Download (download_url, path, () => canceled, (is_percent, progress) => row.install_dialog.progress_text = is_percent? @"$progress%" : Utils.Filesystem.convert_bytes_to_string (progress));

            if (!download_valid) {
                install_error ();
                return false;
            }

            send_message (_("Extracting..."));

            string directory = runner.group.launcher.directory + "/" + runner.group.directory + "/";

            string source_path = yield Utils.Filesystem.extract (directory, title, ".tar.gz", () => canceled);

            if (source_path == "") {
                install_error ();
                return false;
            }

            send_message (_("Renaming..."));

            var runner = this.runner as Runners.Basic;

            var renaming_valid = yield Utils.Filesystem.rename (source_path, directory + runner.get_directory_name (title));

            if (!renaming_valid) {
                install_error ();
                return false;
            }

            send_message (_("Running post installation script..."));

            runner.group.launcher.install (this);

            send_message (_("The installation of %s is complete.").printf (title));

            installed = true;

            return true;
        }

        protected void install_error () {
            if (canceled)
                send_message (_("The installation of %s was canceled.").printf (title));
            else
                send_message (_("An unexpected error occurred while installing %s.").printf (title));
        }

        public virtual async bool remove () {
            send_message (_("The removal of %s has begun.").printf (title));

            var deleted = yield Utils.Filesystem.delete_directory (install_location);

            if (!deleted) {
                remove_error ();
                return false;
            }

            send_message (_("Running post removal script..."));

            runner.group.launcher.uninstall (this);

            send_message (_("The removal of %s is complete.").printf (title));

            installed = false;

            return true;
        }

        protected void remove_error () {
            send_message (_("An unexpected error occurred while removing %s.").printf (title));
        }
    }
}