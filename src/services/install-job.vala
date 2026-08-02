namespace ProtonPlus.Services {
    /// A target-bound, observable installation lifecycle.  A Release remains
    /// reusable catalog data; workflows turn this target into an installed
    /// directory while the job exposes progress and completion to UI and CLI.
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
            TINKERGAME,
        }

        public Models.Release release { get; private set; }
        public Models.Tool tool { get; private set; }
        public Mode mode { get; private set; default = Mode.VERSIONED; }
        public Models.Assets.Asset selected_asset { get; private set; }
        public Models.Providers.ArchiveInstallRequirement archive_install_requirement { get; private set; default = Models.Providers.ArchiveInstallRequirement.STANDARD; }
        public string? selected_variant_name { get; private set; default = null; }
        public string? selected_variant_id { get; private set; default = null; }
        public string install_location { get; private set; default = ""; }
        private string? installation_location_override = null;
        // A replacement backup is a short-lived handoff from the archive
        // transaction to its update finalization, never persisted job state.
        internal string? replacement_backup_path { get; set; default = null; }
        public TinkerGameContext? tinker_game_context { get; private set; default = null; }

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
        /* Recording a restart reminder is advisory.  Keep its outcome on the
         * job so CLI and tests can report it without changing install success. */
        public bool has_steam_restart_record_result { get; internal set; default = false; }
        public SteamRestartRecordResult steam_restart_record_result { get; internal set; default = SteamRestartRecordResult.ALREADY_SATISFIED; }
        public string? steam_restart_warning { get; internal set; default = null; }
        private Models.SteamChangeKind? recorded_steam_change_kind = null;
        public State state { get; internal set; default = State.NOT_INSTALLED; }
        public Step step { get; internal set; default = Step.NOTHING; }
        public signal void progress_updated ();

        public InstallJob (
            Models.Release release,
            Models.Tool tool,
            Mode mode = Mode.VERSIONED,
            string? installation_location_override = null,
            string? tinker_game_home_override = null
        ) {
            this.release = release;
            this.tool = tool;
            this.installation_location_override = installation_location_override;
            selected_asset = release.asset;
            var provider_tool = tool as Models.Tools.ProviderTool;
            if (provider_tool != null)
                archive_install_requirement = provider_tool.archive_install_requirement;
            var is_tinker_game = mode == Mode.TINKERGAME ||
                release.kind == Models.Release.Kind.TINKERGAME;
            this.mode = is_tinker_game ? Mode.TINKERGAME : mode;

            if (is_tinker_game) {
                tinker_game_context = new TinkerGameContext (tool, tinker_game_home_override);
                install_location = tinker_game_context.base_location;
            } else {
                update_install_location (installation_location_override);
            }

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
                var context = tinker_game_context;
                if (context == null)
                    return title;
                if (context.local_date != "")
                    return "%s (%s)".printf (title, context.local_date);
                if (context.latest_date != "")
                    return "%s (%s)".printf (title, context.latest_date);
                return title;
            }
        }

        public string usage_name {
            owned get { return tinker_game_context != null ? "Proton-tg" : title; }
        }

        public string operation_id {
            owned get {
                // Managed Latest and TinkerGame targets may replace
                // their remote Release while the job is active.  Their
                // identity must therefore describe the installation slot,
                // not the currently fetched upstream version, so a revisited
                // view can resolve the in-flight job reliably.
                var release_identity = mode == Mode.VERSIONED
                    ? (release.upstream_release_id != "" ? release.upstream_release_id : release.source_tag)
                    : mode == Mode.LATEST ? "latest" : "tinkergame";
                var variant_id = selected_variant_identity ();
                return "%s/%s/%s/%s/%s".printf (
                    tool.group.launcher.tool_target_id,
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
            case Mode.TINKERGAME:
                return "tinkergame";
            default:
                return "versioned";
            }
        }

        public string get_usage_identifier () {
            if (tinker_game_context != null)
                return usage_name;
            var provider_tool = tool as Models.Tools.ProviderTool;
            if (provider_tool != null) {
                var directory_name = effective_directory_name (provider_tool);
                if (directory_name != "")
                    return directory_name;
            }
            return usage_name;
        }

        public void set_selected_variant (
            string? variant_name,
            Models.Assets.Asset? asset = null,
            string? variant_id = null
        ) {
            selected_variant_name = variant_name;
            selected_variant_id = variant_id;
            if (asset != null)
                selected_asset = asset;
            update_install_location (null);
            refresh_state ();
        }

        public void set_release_for_update (Models.Release release) {
            var previous_variant_id = selected_variant_id;
            var previous_variant_name = selected_variant_name;
            this.release = release;
            selected_asset = release.asset;
            selected_variant_id = previous_variant_id;
            selected_variant_name = previous_variant_name;
            var selected = selected_variant ();
            if (selected != null && selected.download_url != null && selected.download_url != "")
                apply_selected_release_variant (selected);
            update_install_location (null);
            notify_property ("release");
            notify_property ("selected-asset");
            notify_property ("selected-variant-name");
            notify_property ("selected-variant-id");
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

        // Small overridable I/O seams keep transaction characterization tests
        // local without making InstallJob own a filesystem transaction.
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
            recorded_steam_change_kind = null;
            is_finished = false;
            install_success = false;
            error_message = null;
            progress = null;
            speed_kbps = 0.0;
            seconds_remaining = -1.0;
            is_percent = false;
            notify_property ("canceled");
        }

        /* Archive/workflow layers can both observe a successful update.  One
         * job operation may yield only one receipt of each physical change
         * kind; the next operation resets this marker in begin_operation(). */
        internal bool mark_steam_change_recorded (Models.SteamChangeKind kind) {
            if (recorded_steam_change_kind == kind)
                return false;
            recorded_steam_change_kind = kind;
            return true;
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
            InstallationService.instance.refresh_job_state (this);
        }

        internal void apply_selected_release_variant (Models.Variant variant) {
            selected_variant_id = variant.id;
            selected_variant_name = variant.name;
            selected_asset = Models.Assets.Asset.from_download_url ((!) variant.download_url);
            update_install_location (null);
            notify_property ("selected-asset");
            notify_property ("selected-variant-name");
            notify_property ("selected-variant-id");
        }

        internal string selected_variant_identity () {
            if (selected_variant_id != null && selected_variant_id != "")
                return (!) selected_variant_id;
            var selected = selected_variant ();
            if (selected != null)
                return selected.id;
            foreach (var variant in release.variants) {
                if (variant.is_default)
                    return variant.id;
            }
            return "";
        }

        internal string effective_directory_name_for_state () {
            var provider_tool = tool as Models.Tools.ProviderTool;
            return provider_tool != null ? effective_directory_name (provider_tool) : "";
        }

        private Models.Variant? selected_variant () {
            if (selected_variant_id != null && selected_variant_id != "") {
                foreach (var variant in release.variants) {
                    if (variant.id == selected_variant_id)
                        return variant;
                }
            }
            if (selected_variant_name == null || selected_variant_name == "")
                return null;
            foreach (var variant in release.variants) {
                if (variant.name == selected_variant_name)
                    return variant;
            }
            return null;
        }

        private string effective_directory_name (Models.Tools.ProviderTool provider_tool) {
            var name = provider_tool.get_directory_name (title);
            var selected = selected_variant ();
            if (selected == null || selected.is_default)
                return name;
            var suffix = selected.name.replace (" ", "_").replace ("/", "_");
            return "%s-%s".printf (name, suffix);
        }

        private void update_install_location (string? override_location) {
            if (tinker_game_context != null)
                return;
            if (installation_location_override != null) {
                install_location = (!) installation_location_override;
                return;
            }
            if (override_location != null) {
                install_location = override_location;
                return;
            }
            var provider_tool = tool as Models.Tools.ProviderTool;
            if (provider_tool == null)
                return;
            install_location = "%s%s/%s".printf (
                tool.group.launcher.directory,
                tool.group.directory,
                effective_directory_name (provider_tool)
            );
        }
    }
}
