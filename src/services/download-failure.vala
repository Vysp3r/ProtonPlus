namespace ProtonPlus.Services {
    internal enum DownloadOperation {
        INSTALL,
        REPLACEMENT,
        UPDATE,
        PROVIDER_UPDATE,
    }

    /// A snapshot of a completed attempt. The job may be reused by its
    /// original row, so its live progress and error fields cannot describe history.
    public class DownloadFailure : Object {
        internal InstallJob job { get; private set; }
        internal DownloadOperation operation { get; private set; }
        internal string target_key { get; private set; }
        public string tool_title { get; private set; }
        public string release_title { get; private set; }
        public string launcher_title { get; private set; }
        public string message { get; private set; }
        public InstallJob.Step step { get; private set; }
        public ReturnCode code { get; private set; }
        public bool retry_supported { get; private set; }
        public bool retrying { get; internal set; default = false; }

        private string operation_id;
        private string path;
        private Models.Release release;
        private Models.Assets.Asset asset;
        private Posix.Stat destination;
        private bool had_destination;

        public bool is_update {
            get { return operation == DownloadOperation.UPDATE || operation == DownloadOperation.PROVIDER_UPDATE; }
        }

        internal DownloadFailure (InstallJob job, ReturnCode code, DownloadOperation operation, string target_key) {
            this.job = job;
            this.code = code;
            this.operation = operation;
            this.target_key = target_key;
            step = job.last_step;
            tool_title = job.tool.title;
            release_title = job.displayed_title;
            var launcher = job.tool.group.launcher;
            launcher_title = _("%s (%s)").printf (launcher.title, launcher.get_installation_type_title ());
            message = job.error_message != null && job.error_message != ""
                ? (!) job.error_message : get_return_code_message (code);
            operation_id = job.operation_id;
            path = job.install_location;
            release = job.release;
            asset = job.selected_asset;
            had_destination = Posix.lstat (path, out destination) == 0;
            retry_supported = path != "" && (had_destination || Posix.errno == Posix.ENOENT) && is_retryable_failure ();
        }

        public string operation_label () {
            return is_update ? _("Update failed") : _("Installation failed");
        }

        public string stage_label () {
            switch (step) {
            case InstallJob.Step.CHECKING_RELEASE:
                return _("Checking for a release");
            case InstallJob.Step.PREPARING:
                return _("Preparing");
            case InstallJob.Step.DOWNLOADING:
                return _("Downloading");
            case InstallJob.Step.EXTRACTING:
                return _("Extracting");
            case InstallJob.Step.MOVING:
                return _("Installing");
            case InstallJob.Step.FINALIZING:
                return _("Finalizing the update");
            default:
                return "";
            }
        }

        public string copy_details () {
            var stage = stage_label ();
            return "%s\n%s · %s\n%s\n%s%s".printf (
                operation_label (), tool_title, release_title, launcher_title,
                stage != "" ? stage + "\n" : "", message
            );
        }

        internal bool can_retry () {
            if (!retry_supported || job.operation_id != operation_id || job.install_location != path ||
                job.release != release || job.selected_asset != asset ||
                InstallationService.operation_target (path) != target_key)
                return false;
            Posix.Stat current;
            var exists = Posix.lstat (path, out current) == 0;
            if (!exists && Posix.errno != Posix.ENOENT)
                return false;
            return exists == had_destination &&
                (!exists || (current.st_dev == destination.st_dev && current.st_ino == destination.st_ino));
        }

        private bool is_retryable_failure () {
            // Updates can replay against the same directory after a failure
            // before mutation. Direct replacements require a fresh decision.
            if (operation == DownloadOperation.REPLACEMENT)
                return false;
            if (is_update && (!had_destination || !Posix.S_ISDIR (destination.st_mode) ||
                              step == InstallJob.Step.FINALIZING || step == InstallJob.Step.MOVING))
                return false;
            if (operation == DownloadOperation.INSTALL &&
                (had_destination || (job.steam_tinker_launch_context != null && step == InstallJob.Step.MOVING)))
                return false;

            switch (code) {
            case ReturnCode.REQUEST_FAILED:
            case ReturnCode.DOWNLOAD_FAILED:
            case ReturnCode.FILESYSTEM_ERROR:
            case ReturnCode.CONNECTION_ISSUE:
            case ReturnCode.CONNECTION_REFUSED:
            case ReturnCode.CONNECTION_UNKNOWN:
            case ReturnCode.API_LIMIT_REACHED:
            case ReturnCode.INVALID_ACCESS_TOKEN:
            case ReturnCode.TLS_HANDSHAKE_ERROR:
            case ReturnCode.EXTRACTION_FAILED:
            case ReturnCode.RUNNERS_IN_USE:
            case ReturnCode.PROCESS_INSPECTION_FAILED:
                return true;
            default:
                return false;
            }
        }
    }
}
