namespace ProtonPlus.Services {
    /// A target-bound, observable installation lifecycle.  A Release remains
    /// reusable catalog data; this object is the only place where its selected
    /// asset becomes an installed directory and an in-flight operation.
    public class InstallJob : Object {
        public enum Step {
            NOTHING,
            DOWNLOADING,
            EXTRACTING,
            MOVING,
            REMOVING,
        }

        public enum State {
            NOT_INSTALLED,
            UPDATE_AVAILABLE,
            UP_TO_DATE,
            BUSY_INSTALLING,
            BUSY_REMOVING,
            BUSY_UPDATING,
        }

        public enum Mode {
            VERSIONED,
            LATEST,
            STEAM_TINKER_LAUNCH,
        }

        public Models.Release release { get; private set; }
        public Models.Tool tool { get; private set; }
        public Mode mode { get; private set; default = Mode.VERSIONED; }
        public Models.Assets.Asset selected_asset { get; private set; }
        public string? selected_variant_name { get; private set; default = null; }
        public string install_location { get; private set; default = ""; }
        public string? replacement_backup_path { get; internal set; default = null; }

        private Cancellable operation_cancellable = new Cancellable ();
        private bool _canceled = false;
        public bool canceled {
            get { return _canceled; }
            set {
                if (_canceled == value)
                    return;
                _canceled = value;
                if (_canceled)
                    operation_cancellable.cancel ();
                notify_property ("canceled");
            }
        }

        public string? progress { get; internal set; default = null; }
        public double speed_kbps { get; internal set; default = 0.0; }
        public double seconds_remaining { get; internal set; default = -1.0; }
        public bool is_percent { get; internal set; default = false; }
        public bool is_finished { get; internal set; default = false; }
        public bool install_success { get; internal set; default = false; }
        public string? error_message { get; internal set; default = null; }
        public State state { get; internal set; default = State.NOT_INSTALLED; }
        public Step step { get; internal set; default = Step.NOTHING; }
        public signal void progress_updated ();

        // SteamTinkerLaunch's target-specific context.  It is deliberately on
        // the job rather than on a remote Release subclass.
        internal string stl_home_location { get; private set; default = ""; }
        internal string stl_base_location { get; private set; default = ""; }
        internal string stl_binary_location { get; private set; default = ""; }
        internal string stl_meta_location { get; private set; default = ""; }
        internal string stl_link_parent_location { get; private set; default = ""; }
        internal string stl_link_location { get; private set; default = ""; }
        internal string stl_config_location { get; private set; default = ""; }
        internal string stl_manual_remove_location { get; private set; default = ""; }
        internal string stl_compat_location { get; private set; default = ""; }
        internal string stl_latest_date { get; set; default = ""; }
        internal string stl_latest_hash { get; set; default = ""; }
        internal string stl_local_date { get; set; default = ""; }
        internal string stl_local_hash { get; set; default = ""; }
        internal List<string> stl_external_locations;
        public bool stl_remove_config { get; set; default = false; }
        public bool stl_user_requested_removal { get; set; default = false; }

        public InstallJob (
            Models.Release release,
            Models.Tool tool,
            Mode mode = Mode.VERSIONED,
            string? installation_location_override = null,
            string? stl_home_override = null
        ) {
            this.release = release;
            this.tool = tool;
            this.mode = mode;
            this.selected_asset = release.asset;
            this.stl_external_locations = new List<string> ();

            if (mode == Mode.STEAM_TINKER_LAUNCH)
                configure_steam_tinker_launch (stl_home_override);
            else
                update_install_location (installation_location_override);

            refresh_state ();
        }

        public string title {
            owned get {
                if (mode == Mode.LATEST)
                    return "%s Latest".printf (tool.title);
                return release.title;
            }
        }

        public string displayed_title {
            owned get {
                if (mode != Mode.STEAM_TINKER_LAUNCH)
                    return title;
                if (stl_local_date != "")
                    return "%s (%s)".printf (title, stl_local_date);
                if (stl_latest_date != "")
                    return "%s (%s)".printf (title, stl_latest_date);
                return title;
            }
        }

        public string usage_name {
            owned get { return mode == Mode.STEAM_TINKER_LAUNCH ? "Proton-stl" : title; }
        }

        public string operation_id {
            owned get {
                // Managed Latest and SteamTinkerLaunch targets may replace
                // their remote Release while the job is active.  Their
                // identity must therefore describe the installation slot,
                // not the currently fetched upstream version, so a revisited
                // view can resolve the in-flight job reliably.
                var release_identity = mode == Mode.VERSIONED
                    ? (release.upstream_release_id != "" ? release.upstream_release_id : release.source_tag)
                    : mode == Mode.LATEST ? "latest" : "steam-tinker-launch";
                var variant_id = selected_variant_id ();
                return "%s/%s/%s/%s/%s".printf (
                    tool.group.launcher.instance_id,
                    tool.id,
                    mode_id (),
                    release_identity,
                    variant_id
                );
            }
        }

        private string mode_id () {
            switch (mode) {
            case Mode.LATEST:
                return "latest";
            case Mode.STEAM_TINKER_LAUNCH:
                return "steam-tinker-launch";
            default:
                return "versioned";
            }
        }

        public string get_usage_identifier () {
            if (mode == Mode.STEAM_TINKER_LAUNCH)
                return usage_name;
            var basic_tool = tool as Models.Tools.Basic;
            if (basic_tool != null) {
                var directory_name = effective_directory_name (basic_tool);
                if (directory_name != "")
                    return directory_name;
            }
            return usage_name;
        }

        public void set_selected_variant (string? variant_name, Models.Assets.Asset? asset = null) {
            selected_variant_name = variant_name;
            if (asset != null)
                selected_asset = asset;
            update_install_location (null);
            refresh_state ();
        }

        public void set_release_for_update (Models.Release release) {
            var previous_variant_name = selected_variant_name;
            this.release = release;
            selected_asset = release.asset;
            selected_variant_name = null;
            if (previous_variant_name != null && previous_variant_name != "") {
                foreach (var variant in release.variants) {
                    if (variant.name != previous_variant_name)
                        continue;
                    selected_variant_name = variant.name;
                    if (variant.download_url != null && variant.download_url != "")
                        selected_asset = Models.Assets.Asset.from_download_url (variant.download_url);
                    break;
                }
            }
            update_install_location (null);
            notify_property ("release");
            notify_property ("selected-asset");
            notify_property ("selected-variant-name");
        }

        public async ReturnCode install () {
            return yield InstallationService.instance.install (this, false);
        }

        public async ReturnCode install_replacement () {
            return yield InstallationService.instance.install (this, true);
        }

        public async ReturnCode update () {
            return yield InstallationService.instance.update (this);
        }

        public async ReturnCode remove (bool notify_removal = false) {
            return yield InstallationService.instance.remove (this, notify_removal);
        }

        // Small overridable seams keep transaction characterization tests local
        // without moving workflow ownership back into Release.
        public virtual async bool download_archive (string url, string path, out string? error_message) {
            return yield Utils.Web.download (url, path, operation_cancellable, report_progress, out error_message);
        }

        public virtual async bool promote_staged_installation (string staged_install_path) {
            return yield Utils.Filesystem.move_directory_atomic (staged_install_path, install_location);
        }

        internal Cancellable get_cancellable () {
            return operation_cancellable;
        }

        internal void begin_operation () {
            _canceled = false;
            operation_cancellable = new Cancellable ();
            replacement_backup_path = null;
            is_finished = false;
            install_success = false;
            error_message = null;
            progress = null;
            speed_kbps = 0.0;
            seconds_remaining = -1.0;
            is_percent = false;
            notify_property ("canceled");
        }

        // Keep the busy state until the service has finished cleanup and
        // removed the operation from the manager.  Only then may the row
        // inspect the filesystem again and return to its idle actions.
        internal void finish_operation () {
            if (state == State.BUSY_INSTALLING || state == State.BUSY_REMOVING || state == State.BUSY_UPDATING)
                state = State.NOT_INSTALLED;
            refresh_state ();
        }

        internal void report_progress (bool is_percent, int64 progress, double speed_kbps, double? remaining_seconds) {
            this.is_percent = is_percent;
            this.progress = is_percent ? "%s%%".printf (progress.to_string ()) : Utils.Filesystem.convert_bytes_to_string (progress);
            this.speed_kbps = speed_kbps;
            this.seconds_remaining = remaining_seconds ?? -1.0;
            progress_updated ();
            Utils.DownloadManager.instance.progress_updated (this);
        }

        public void refresh_state () {
            if (state == State.BUSY_INSTALLING || state == State.BUSY_REMOVING || state == State.BUSY_UPDATING)
                return;

            step = Step.NOTHING;
            if (mode == Mode.STEAM_TINKER_LAUNCH) {
                refresh_steam_tinker_launch_state ();
                return;
            }

            var basic_tool = tool as Models.Tools.Basic;
            var directory_valid = basic_tool != null && effective_directory_name (basic_tool) != "";
            var installed = install_location != "" && FileUtils.test (install_location, FileTest.IS_DIR);
            if (mode == Mode.LATEST && basic_tool != null) {
                var backup = "%s%s/%s Latest Backup".printf (tool.group.launcher.directory, tool.group.directory, tool.title);
                installed = installed || FileUtils.test (backup, FileTest.IS_DIR);
            }
            state = directory_valid && installed ? State.UP_TO_DATE : State.NOT_INSTALLED;
        }

        internal void refresh_steam_tinker_launch_state () {
            var installed = FileUtils.test (stl_base_location, FileTest.IS_DIR)
                && FileUtils.test (stl_binary_location, FileTest.IS_EXECUTABLE)
                && FileUtils.test (stl_meta_location, FileTest.IS_REGULAR);
            var updated = false;
            stl_local_date = "";
            stl_local_hash = "";

            if (installed) {
                var parts = Utils.Filesystem.get_file_content (stl_meta_location).strip ().split (":");
                if (parts.length >= 2) {
                    stl_local_date = parts[0];
                    stl_local_hash = parts[1];
                    if (stl_local_date == "" || stl_local_hash == "")
                        stl_local_date = stl_local_hash = "";
                }
                if (stl_local_hash == "")
                    installed = false;
                else if (stl_latest_hash != "")
                    updated = stl_latest_hash == stl_local_hash;
            }
            state = !installed ? State.NOT_INSTALLED : updated ? State.UP_TO_DATE : State.UPDATE_AVAILABLE;
            step = Step.NOTHING;
        }

        public bool detect_external_steam_tinker_launch_locations () {
            stl_external_locations = new List<string> ();
            var location = "%s/SteamTinkerLaunch".printf (stl_home_location);
            if (FileUtils.test (location, FileTest.IS_DIR))
                stl_external_locations.append (location);
            location = Environment.get_home_dir () + "/stl";
            if (!Globals.IS_STEAM_OS && FileUtils.test (location, FileTest.IS_DIR))
                stl_external_locations.append (location);
            return stl_external_locations.length () > 0;
        }

        private void configure_steam_tinker_launch (string? home_override) {
            stl_home_location = home_override ?? Environment.get_home_dir ();
            stl_compat_location = tool.group.launcher.directory + tool.group.directory;
            if (Globals.IS_STEAM_OS) {
                stl_base_location = "%s/stl/prefix".printf (stl_home_location);
                stl_manual_remove_location = "%s/stl".printf (stl_home_location);
            } else {
                stl_base_location = "%s/.local/share/steamtinkerlaunch".printf (stl_home_location);
                stl_manual_remove_location = stl_base_location;
            }
            stl_binary_location = "%s/steamtinkerlaunch".printf (stl_base_location);
            stl_meta_location = "%s/ProtonPlus.meta".printf (stl_base_location);
            stl_link_parent_location = "%s/.local/bin".printf (stl_home_location);
            stl_link_location = "%s/steamtinkerlaunch".printf (stl_link_parent_location);
            stl_config_location = "%s/.config/steamtinkerlaunch".printf (stl_home_location);
            install_location = stl_base_location;
        }

        private Models.Variant? selected_variant () {
            if (selected_variant_name == null || selected_variant_name == "")
                return null;
            foreach (var variant in release.variants) {
                if (variant.name == selected_variant_name)
                    return variant;
            }
            return null;
        }

        internal string selected_variant_id () {
            var selected = selected_variant ();
            if (selected != null)
                return selected.id;
            foreach (var variant in release.variants) {
                if (variant.is_default)
                    return variant.id;
            }
            return "";
        }

        private string effective_directory_name (Models.Tools.Basic basic_tool) {
            var name = basic_tool.get_directory_name (title);
            var selected = selected_variant ();
            if (selected == null || selected.is_default)
                return name;
            var suffix = selected.name.replace (" ", "_").replace ("/", "_");
            return "%s-%s".printf (name, suffix);
        }

        private void update_install_location (string? override_location) {
            if (mode == Mode.STEAM_TINKER_LAUNCH)
                return;
            if (override_location != null) {
                install_location = override_location;
                return;
            }
            var basic_tool = tool as Models.Tools.Basic;
            if (basic_tool == null)
                return;
            install_location = "%s%s/%s".printf (
                tool.group.launcher.directory,
                tool.group.directory,
                effective_directory_name (basic_tool)
            );
        }
    }
}
