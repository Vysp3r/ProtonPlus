namespace ProtonPlus.Models {
    /* This identifies one replayable field, never an entire VDF snapshot. */
    public enum SteamConfigurationFile { CONFIG, LOCALCONFIG, SHORTCUTS }
    public enum SteamConfigurationOperation {
        COMPATIBILITY_MAPPING, LAUNCH_OPTIONS, SHORTCUT_LAUNCH_OPTIONS,
        SHORTCUTS_FILE_PRESENT, SHORTCUT_PRESENCE
    }

    public class SteamConfigurationIntent : Object {
        public SteamConfigurationFile file { get; private set; }
        public SteamConfigurationOperation operation { get; private set; }
        public string path { get; private set; }
        public string field_id { get; private set; }
        /* A baseline is intentionally kept in memory for the lifetime of a
         * staged edit, but is serialized as a fingerprint.  Desired values
         * remain replayable state and are protected by the private state file. */
        public string baseline { get; private set; }
        public string baseline_fingerprint { get; private set; }
        public string desired { get; private set; }
        public bool baseline_present { get; private set; }
        public bool desired_present { get; private set; }

        public SteamConfigurationIntent (SteamConfigurationFile file,
            SteamConfigurationOperation operation, string path, string field_id,
            string baseline, string desired, bool baseline_present = true,
            bool desired_present = true, string? baseline_fingerprint = null) {
            this.file = file; this.operation = operation; this.path = path;
            this.field_id = field_id; this.baseline = baseline;
            this.desired = desired;
            this.baseline_present = baseline_present;
            this.desired_present = desired_present;
            this.baseline_fingerprint = baseline_fingerprint ?? fingerprint (baseline, baseline_present);
        }

        public static string file_to_identifier (SteamConfigurationFile file) {
            switch (file) {
            case SteamConfigurationFile.CONFIG: return "config";
            case SteamConfigurationFile.LOCALCONFIG: return "localconfig";
            case SteamConfigurationFile.SHORTCUTS: return "shortcuts";
            default: return "unknown";
            }
        }

        public static bool try_file_from_identifier (string value, out SteamConfigurationFile file) {
            file = SteamConfigurationFile.CONFIG;
            switch (value) {
            case "config": file = SteamConfigurationFile.CONFIG; return true;
            case "localconfig": file = SteamConfigurationFile.LOCALCONFIG; return true;
            case "shortcuts": file = SteamConfigurationFile.SHORTCUTS; return true;
            default: return false;
            }
        }

        public static string operation_to_identifier (SteamConfigurationOperation operation) {
            switch (operation) {
            case SteamConfigurationOperation.COMPATIBILITY_MAPPING: return "compatibility-mapping";
            case SteamConfigurationOperation.LAUNCH_OPTIONS: return "launch-options";
            case SteamConfigurationOperation.SHORTCUT_LAUNCH_OPTIONS: return "shortcut-launch-options";
            case SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT: return "shortcuts-file-present";
            case SteamConfigurationOperation.SHORTCUT_PRESENCE: return "shortcut-presence";
            default: return "unknown";
            }
        }

        public static bool try_operation_from_identifier (string value, out SteamConfigurationOperation operation) {
            operation = SteamConfigurationOperation.COMPATIBILITY_MAPPING;
            switch (value) {
            case "compatibility-mapping": operation = SteamConfigurationOperation.COMPATIBILITY_MAPPING; return true;
            case "launch-options": operation = SteamConfigurationOperation.LAUNCH_OPTIONS; return true;
            case "shortcut-launch-options": operation = SteamConfigurationOperation.SHORTCUT_LAUNCH_OPTIONS; return true;
            case "shortcuts-file-present": operation = SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT; return true;
            case "shortcut-presence": operation = SteamConfigurationOperation.SHORTCUT_PRESENCE; return true;
            default: return false;
            }
        }

        public static string fingerprint (string value, bool present) {
            var checksum = new Checksum (ChecksumType.SHA256);
            var material = (present ? "present\u001f" : "absent\u001f") + value;
            checksum.update (material.data, material.length);
            return checksum.get_string ();
        }
    }

    /* These identifiers are a persistence contract.  Do not use enum ordinals
     * or translated labels in restart-state storage. */
    public enum SteamChangeKind {
        DEFAULT_COMPATIBILITY_TOOL_CHANGED,
        GAME_COMPATIBILITY_TOOL_CHANGED,
        STEAM_GAME_LAUNCH_OPTIONS_CHANGED,
        NON_STEAM_GAME_LAUNCH_OPTIONS_CHANGED,
        PROTONPLUS_SHORTCUT_CREATED,
        PROTONPLUS_SHORTCUT_REMOVED,
        SHORTCUTS_VDF_CREATED,
        COMPATIBILITY_TOOL_INSTALLED,
        COMPATIBILITY_TOOL_REMOVED,
        COMPATIBILITY_TOOL_UPDATED_OR_REPLACED,
        STEAMTINKERLAUNCH_CHANGED
    }

    public enum SteamRestartRequirement {
        DOCUMENTED,
        CONSERVATIVE
    }

    public class SteamChangeReceipt : Object {
        public SteamRestartTarget target { get; private set; }
        public SteamChangeKind kind { get; private set; }
        public SteamRestartRequirement restart_requirement { get; private set; }
        public string resource_key { get; private set; }
        public string? subject_id { get; private set; }
        public string? subject_label { get; private set; }
        public string changed_at { get; private set; }
        public SteamConfigurationIntent? configuration_intent { get; private set; }

        public SteamChangeReceipt (
            SteamRestartTarget target, SteamChangeKind kind,
            SteamRestartRequirement restart_requirement, string resource_key,
            string? subject_id = null, string? subject_label = null,
            string? changed_at = null, SteamConfigurationIntent? configuration_intent = null
        ) {
            this.target = target;
            this.kind = kind;
            this.restart_requirement = restart_requirement;
            this.resource_key = resource_key;
            this.subject_id = subject_id;
            this.subject_label = subject_label;
            this.changed_at = changed_at ?? new DateTime.now_utc ().format_iso8601 ();
            this.configuration_intent = configuration_intent;
        }

        public string deduplication_key {
            owned get { return "%s\u001f%s\u001f%s".printf (target.id, kind_to_identifier (kind), resource_key); }
        }

        public static string kind_to_identifier (SteamChangeKind kind) {
            switch (kind) {
            case SteamChangeKind.DEFAULT_COMPATIBILITY_TOOL_CHANGED: return "default-compatibility-tool-changed";
            case SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED: return "game-compatibility-tool-changed";
            case SteamChangeKind.STEAM_GAME_LAUNCH_OPTIONS_CHANGED: return "steam-game-launch-options-changed";
            case SteamChangeKind.NON_STEAM_GAME_LAUNCH_OPTIONS_CHANGED: return "non-steam-game-launch-options-changed";
            case SteamChangeKind.PROTONPLUS_SHORTCUT_CREATED: return "protonplus-shortcut-created";
            case SteamChangeKind.PROTONPLUS_SHORTCUT_REMOVED: return "protonplus-shortcut-removed";
            case SteamChangeKind.SHORTCUTS_VDF_CREATED: return "shortcuts-vdf-created";
            case SteamChangeKind.COMPATIBILITY_TOOL_INSTALLED: return "compatibility-tool-installed";
            case SteamChangeKind.COMPATIBILITY_TOOL_REMOVED: return "compatibility-tool-removed";
            case SteamChangeKind.COMPATIBILITY_TOOL_UPDATED_OR_REPLACED: return "compatibility-tool-updated-or-replaced";
            case SteamChangeKind.STEAMTINKERLAUNCH_CHANGED: return "steamtinkerlaunch-changed";
            default: return "unknown";
            }
        }

        public static bool try_kind_from_identifier (string value, out SteamChangeKind kind) {
            kind = SteamChangeKind.DEFAULT_COMPATIBILITY_TOOL_CHANGED;
            switch (value) {
            case "default-compatibility-tool-changed": kind = SteamChangeKind.DEFAULT_COMPATIBILITY_TOOL_CHANGED; return true;
            case "game-compatibility-tool-changed": kind = SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED; return true;
            case "steam-game-launch-options-changed": kind = SteamChangeKind.STEAM_GAME_LAUNCH_OPTIONS_CHANGED; return true;
            case "non-steam-game-launch-options-changed": kind = SteamChangeKind.NON_STEAM_GAME_LAUNCH_OPTIONS_CHANGED; return true;
            case "protonplus-shortcut-created": kind = SteamChangeKind.PROTONPLUS_SHORTCUT_CREATED; return true;
            case "protonplus-shortcut-removed": kind = SteamChangeKind.PROTONPLUS_SHORTCUT_REMOVED; return true;
            case "shortcuts-vdf-created": kind = SteamChangeKind.SHORTCUTS_VDF_CREATED; return true;
            case "compatibility-tool-installed": kind = SteamChangeKind.COMPATIBILITY_TOOL_INSTALLED; return true;
            case "compatibility-tool-removed": kind = SteamChangeKind.COMPATIBILITY_TOOL_REMOVED; return true;
            case "compatibility-tool-updated-or-replaced": kind = SteamChangeKind.COMPATIBILITY_TOOL_UPDATED_OR_REPLACED; return true;
            case "steamtinkerlaunch-changed": kind = SteamChangeKind.STEAMTINKERLAUNCH_CHANGED; return true;
            default: return false;
            }
        }

        public static string requirement_to_identifier (SteamRestartRequirement requirement) {
            return requirement == SteamRestartRequirement.DOCUMENTED ? "documented" : "conservative";
        }

        public static SteamRestartRequirement default_requirement_for_kind (SteamChangeKind kind) {
            return kind == SteamChangeKind.COMPATIBILITY_TOOL_INSTALLED
                ? SteamRestartRequirement.DOCUMENTED
                : SteamRestartRequirement.CONSERVATIVE;
        }

        public static bool try_requirement_from_identifier (string value, out SteamRestartRequirement requirement) {
            requirement = SteamRestartRequirement.CONSERVATIVE;
            if (value == "documented") {
                requirement = SteamRestartRequirement.DOCUMENTED;
                return true;
            }
            if (value == "conservative")
                return true;
            return false;
        }
    }

    public class SteamSessionIdentity : Object {
        public string? boot_id { get; private set; }
        public int64 process_start_ticks { get; private set; }
        public int process_pid { get; private set; }
        public string? flatpak_instance_id { get; private set; }

        public SteamSessionIdentity (string? boot_id, int64 process_start_ticks, int process_pid, string? flatpak_instance_id) {
            this.boot_id = boot_id;
            this.process_start_ticks = process_start_ticks;
            this.process_pid = process_pid;
            this.flatpak_instance_id = flatpak_instance_id;
        }

        public bool equals (SteamSessionIdentity other) {
            if (flatpak_instance_id != null || other.flatpak_instance_id != null)
                return flatpak_instance_id == other.flatpak_instance_id;
            return boot_id == other.boot_id && process_start_ticks == other.process_start_ticks && process_pid == other.process_pid;
        }
    }

    public class SteamRestartPendingRecord : Object {
        public SteamChangeReceipt receipt { get; private set; }
        public string first_recorded_at { get; private set; }
        public string last_updated_at { get; private set; }
        public uint occurrence_count { get; private set; }
        public SteamSessionIdentity? observed_session { get; private set; }
        public bool stop_observed { get; private set; }

        public SteamRestartPendingRecord (
            SteamChangeReceipt receipt, string first_recorded_at, string last_updated_at,
            uint occurrence_count, SteamSessionIdentity? observed_session, bool stop_observed = false
        ) {
            this.receipt = receipt;
            this.first_recorded_at = first_recorded_at;
            this.last_updated_at = last_updated_at;
            this.occurrence_count = occurrence_count;
            this.observed_session = observed_session;
            this.stop_observed = stop_observed;
        }

        public void update (SteamChangeReceipt receipt, SteamSessionIdentity? session) {
            this.receipt = receipt;
            this.last_updated_at = receipt.changed_at;
            occurrence_count++;
            if (observed_session == null && session != null)
                observed_session = session;
        }

        public bool mark_stop_observed () {
            if (stop_observed)
                return false;
            stop_observed = true;
            return true;
        }
    }
}
