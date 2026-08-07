namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    public class SteamRestartStateLoadResult : Object {
        public Gee.List<SteamRestartPendingRecord> records { get; private set; }
        public string? error { get; private set; }

        public SteamRestartStateLoadResult (Gee.List<SteamRestartPendingRecord> records, string? error = null) {
            this.records = records;
            this.error = error;
        }
    }

    /* This is deliberately state data, not cache data: cache deletion must not
     * discard an outstanding requirement to restart Steam. */
    public class SteamRestartStateStore : Object {
        private const int SCHEMA_VERSION = 2;
        public string path { get; private set; }
        public string? last_error { get; private set; default = null; }

        public SteamRestartStateStore (string? path = null) {
            this.path = path ?? Path.build_filename (Environment.get_user_state_dir (), "ProtonPlus", "steam-restart-state.json");
        }

        public SteamRestartStateLoadResult load () {
            var records = new Gee.ArrayList<SteamRestartPendingRecord> ();
            last_error = null;
            if (!FileUtils.test (path, FileTest.EXISTS))
                return new SteamRestartStateLoadResult (records);

            string content;
            try {
                FileUtils.get_contents (path, out content);
            } catch (FileError e) {
                last_error = "Unable to read Steam restart state: %s".printf (e.message);
                return new SteamRestartStateLoadResult (records, last_error);
            }

            Json.Node? root;
            try {
                root = Json.from_string (content);
            } catch (Error e) {
                last_error = "Steam restart state is malformed JSON.";
                return new SteamRestartStateLoadResult (records, last_error);
            }
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                last_error = "Steam restart state has an invalid root object.";
                return new SteamRestartStateLoadResult (records, last_error);
            }
            var object = root.get_object ();
            var version = object.get_int_member_with_default ("schema_version", 0);
            if (version != 1 && version != SCHEMA_VERSION) {
                last_error = "Steam restart state uses an unsupported schema version.";
                return new SteamRestartStateLoadResult (records, last_error);
            }
            var entries = object.get_member ("records");
            if (entries == null || entries.get_node_type () != Json.NodeType.ARRAY) {
                last_error = "Steam restart state has no valid records array.";
                return new SteamRestartStateLoadResult (records, last_error);
            }
            var array = entries.get_array ();
            for (var i = 0; i < array.get_length (); i++) {
                var record = record_from_json (array.get_object_element (i), (int) version);
                if (record != null)
                    records.add (record);
                else
                    last_error = "Some Steam restart records were rejected for safety.";
            }
            return new SteamRestartStateLoadResult (records, last_error);
        }

        public virtual bool save (Gee.Collection<SteamRestartPendingRecord> records) {
            last_error = null;
            var parent = File.new_for_path (Path.get_dirname (path));
            try {
                parent.make_directory_with_parents (null);
            } catch (Error e) {
                if (!parent.query_exists (null)) {
                    last_error = "Unable to create Steam restart state directory: %s".printf (e.message);
                    return false;
                }
            }

            var root = new Json.Object ();
            root.set_int_member ("schema_version", SCHEMA_VERSION);
            var array = new Json.Array ();
            foreach (var record in records)
                array.add_object_element (record_to_json (record));
            root.set_array_member ("records", array);
            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (root);
            var generator = new Json.Generator ();
            generator.set_root (node);
            var data = generator.to_data (null);

            try {
                /* PRIVATE only affects a newly created file.  Secure an
                 * existing replacement before changing its contents so a
                 * permission failure cannot split memory from durable state. */
                if (FileUtils.test (path, FileTest.EXISTS) && Posix.chmod (path, 0600) != 0) {
                    last_error = "Unable to secure Steam restart state file.";
                    return false;
                }
                string? etag;
                File.new_for_path (path).replace_contents (data.data, null, false, FileCreateFlags.PRIVATE, out etag, null);
                return true;
            } catch (Error e) {
                last_error = "Unable to save Steam restart state: %s".printf (e.message);
                return false;
            }
        }

        private Json.Object record_to_json (SteamRestartPendingRecord record) {
            var object = new Json.Object ();
            object.set_object_member ("target", target_to_json (record.receipt.target));
            object.set_string_member ("kind", SteamChangeReceipt.kind_to_identifier (record.receipt.kind));
            object.set_string_member ("requirement", SteamChangeReceipt.requirement_to_identifier (record.receipt.restart_requirement));
            object.set_string_member ("resource_key", record.receipt.resource_key);
            object.set_string_member ("changed_at", record.receipt.changed_at);
            if (record.receipt.subject_id != null)
                object.set_string_member ("subject_id", (!) record.receipt.subject_id);
            if (record.receipt.subject_label != null)
                object.set_string_member ("subject_label", (!) record.receipt.subject_label);
            object.set_string_member ("first_recorded_at", record.first_recorded_at);
            object.set_string_member ("last_updated_at", record.last_updated_at);
            object.set_int_member ("occurrence_count", record.occurrence_count);
            object.set_boolean_member ("stop_observed", record.stop_observed);
            if (record.observed_session != null)
                object.set_object_member ("observed_session", session_to_json ((!) record.observed_session));
            if (record.receipt.configuration_intent != null)
                object.set_object_member ("configuration_intent", intent_to_json ((!) record.receipt.configuration_intent));
            return object;
        }

        private SteamRestartPendingRecord? record_from_json (Json.Object? object, int schema_version) {
            if (object == null)
                return null;
            var target_node = object.get_member ("target");
            if (target_node == null || target_node.get_node_type () != Json.NodeType.OBJECT)
                return null;
            var target = target_from_json (target_node.get_object ());
            if (target == null)
                return null;
            SteamChangeKind kind = SteamChangeKind.DEFAULT_COMPATIBILITY_TOOL_CHANGED;
            SteamRestartRequirement requirement = SteamRestartRequirement.CONSERVATIVE;
            var resource_key = object.get_string_member_with_default ("resource_key", "");
            var changed_at = object.get_string_member_with_default ("changed_at", "");
            var first_recorded_at = object.get_string_member_with_default ("first_recorded_at", "");
            var last_updated_at = object.get_string_member_with_default ("last_updated_at", "");
            if (resource_key == "" || changed_at == "" || first_recorded_at == "" || last_updated_at == ""
                || !SteamChangeReceipt.try_kind_from_identifier (object.get_string_member_with_default ("kind", ""), out kind)
                || !SteamChangeReceipt.try_requirement_from_identifier (object.get_string_member_with_default ("requirement", ""), out requirement))
                return null;
            var count = object.get_int_member_with_default ("occurrence_count", 0);
            if (count < 1 || count > uint.MAX)
                return null;
            SteamSessionIdentity? session = null;
            var session_node = object.get_member ("observed_session");
            if (session_node != null) {
                if (session_node.get_node_type () != Json.NodeType.OBJECT)
                    return null;
                session = session_from_json (session_node.get_object ());
                if (session == null)
                    return null;
            }
            SteamConfigurationIntent? intent = null;
            var intent_node = object.get_member ("configuration_intent");
            if (intent_node != null) {
                if (intent_node.get_node_type () != Json.NodeType.OBJECT)
                    return null;
                intent = intent_from_json (intent_node.get_object (), schema_version, target, resource_key, kind);
                if (intent == null)
                    return null;
            }
            var receipt = new SteamChangeReceipt (target, kind, requirement, resource_key,
                optional_string (object, "subject_id"), optional_string (object, "subject_label"), changed_at, intent);
            return new SteamRestartPendingRecord (receipt, first_recorded_at, last_updated_at,
                (uint) count, session, object.get_boolean_member_with_default ("stop_observed", false));
        }

        private Json.Object target_to_json (SteamRestartTarget target) {
            var object = new Json.Object ();
            object.set_string_member ("id", target.id);
            object.set_string_member ("data_root", target.data_root);
            object.set_string_member ("installation_kind", installation_kind_to_identifier (target.installation_kind));
            object.set_string_member ("display_name", target.display_name);
            if (target.flatpak_application_id != null)
                object.set_string_member ("flatpak_application_id", (!) target.flatpak_application_id);
            if (target.executable_hint != null)
                object.set_string_member ("executable_hint", (!) target.executable_hint);
            if (target.desktop_entry_id != null)
                object.set_string_member ("desktop_entry_id", (!) target.desktop_entry_id);
            object.set_boolean_member ("storage_only", target.storage_only);
            return object;
        }

        private Json.Object intent_to_json (SteamConfigurationIntent intent) {
            var object = new Json.Object ();
            object.set_string_member ("file", SteamConfigurationIntent.file_to_identifier (intent.file));
            object.set_string_member ("operation", SteamConfigurationIntent.operation_to_identifier (intent.operation));
            object.set_string_member ("path", intent.path);
            object.set_string_member ("field_id", intent.field_id);
            object.set_string_member ("baseline_fingerprint", intent.baseline_fingerprint);
            object.set_boolean_member ("baseline_present", intent.baseline_present);
            object.set_string_member ("desired", intent.desired);
            object.set_boolean_member ("desired_present", intent.desired_present);
            return object;
        }

        private SteamConfigurationIntent? intent_from_json (Json.Object object, int schema_version,
            SteamRestartTarget target, string resource_key, SteamChangeKind kind) {
            SteamConfigurationFile file = SteamConfigurationFile.CONFIG;
            SteamConfigurationOperation operation = SteamConfigurationOperation.COMPATIBILITY_MAPPING;
            if (schema_version == 1) {
                var legacy_file = object.get_int_member_with_default ("file", -1);
                var legacy_operation = object.get_int_member_with_default ("operation", -1);
                if (legacy_file < (int) SteamConfigurationFile.CONFIG || legacy_file > (int) SteamConfigurationFile.SHORTCUTS
                    || legacy_operation < (int) SteamConfigurationOperation.COMPATIBILITY_MAPPING
                    || legacy_operation > (int) SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT)
                    return null;
                file = (SteamConfigurationFile) legacy_file;
                operation = (SteamConfigurationOperation) legacy_operation;
            } else if (!SteamConfigurationIntent.try_file_from_identifier (object.get_string_member_with_default ("file", ""), out file)
                || !SteamConfigurationIntent.try_operation_from_identifier (object.get_string_member_with_default ("operation", ""), out operation)) {
                return null;
            }
            var path = object.get_string_member_with_default ("path", "");
            var field_id = object.get_string_member_with_default ("field_id", "");
            if (path == "" || field_id == "" || !object.has_member ("desired")
                || !is_valid_intent (target, kind, file, operation, path, field_id, resource_key))
                return null;
            var desired = object.get_string_member ("desired");
            if (schema_version == 1) {
                if (!object.has_member ("baseline")) return null;
                var baseline = object.get_string_member ("baseline");
                const string legacy_absent = "\u001eprotonplus-absent";
                var baseline_present = baseline != legacy_absent;
                var desired_present = desired != legacy_absent;
                return new SteamConfigurationIntent (file, operation, path, field_id,
                    baseline_present ? baseline : "", desired_present ? desired : "",
                    baseline_present, desired_present);
            }
            var fingerprint = object.get_string_member_with_default ("baseline_fingerprint", "");
            if (fingerprint == "") return null;
            return new SteamConfigurationIntent (file, operation, path, field_id, "", desired,
                object.get_boolean_member_with_default ("baseline_present", true),
                object.get_boolean_member_with_default ("desired_present", true), fingerprint);
        }

        private bool is_valid_intent (SteamRestartTarget target, SteamChangeKind kind,
            SteamConfigurationFile file, SteamConfigurationOperation operation,
            string path, string field_id, string resource_key) {
            var canonical = Filename.canonicalize (path, null);
            if (canonical != path) return false;
            var config = Path.build_filename (target.data_root, "config", "config.vdf");
            if (file == SteamConfigurationFile.CONFIG)
                return operation == SteamConfigurationOperation.COMPATIBILITY_MAPPING
                    && canonical == config && path_resolves_inside (path, config)
                    && is_uint (field_id)
                    && resource_key == "%s#CompatToolMapping/%s".printf (path, field_id)
                    && (kind == SteamChangeKind.DEFAULT_COMPATIBILITY_TOOL_CHANGED
                        || kind == SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED);
            var prefix = Path.build_filename (target.data_root, "userdata") + "/";
            if (!canonical.has_prefix (prefix)) return false;
            var tail = canonical.substring (prefix.length);
            var parts = tail.split ("/");
            if (parts.length != 3 || !is_uint (parts[0]) || parts[1] != "config") return false;
            var profile_config = Path.build_filename (target.data_root, "userdata", parts[0], "config");
            /* The target normalizes its data root with realpath().  Resolve
             * the existing config directory too: a textual path below it is
             * not safe when a profile component is a symlink to elsewhere. */
            if (!directory_is_expected_or_missing (Path.get_dirname (path), profile_config)) return false;
            if (file == SteamConfigurationFile.LOCALCONFIG)
                return operation == SteamConfigurationOperation.LAUNCH_OPTIONS && parts[2] == "localconfig.vdf"
                    && is_uint (field_id) && resource_key == "%s#%s/LaunchOptions".printf (path, field_id)
                    && kind == SteamChangeKind.STEAM_GAME_LAUNCH_OPTIONS_CHANGED;
            if (file != SteamConfigurationFile.SHORTCUTS || parts[2] != "shortcuts.vdf") return false;
            if (operation == SteamConfigurationOperation.SHORTCUT_LAUNCH_OPTIONS)
                return is_uint (field_id) && resource_key == "%s#shortcut/%s/LaunchOptions".printf (path, field_id)
                    && kind == SteamChangeKind.NON_STEAM_GAME_LAUNCH_OPTIONS_CHANGED;
            if (operation == SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT)
                return field_id == "shortcuts.vdf" && resource_key == "%s#shortcuts.vdf".printf (path)
                    && kind == SteamChangeKind.SHORTCUTS_VDF_CREATED;
            return operation == SteamConfigurationOperation.SHORTCUT_PRESENCE && field_id == "ProtonPlus"
                && resource_key == "%s#ProtonPlus".printf (path)
                && (kind == SteamChangeKind.PROTONPLUS_SHORTCUT_CREATED || kind == SteamChangeKind.PROTONPLUS_SHORTCUT_REMOVED);
        }

        private bool path_resolves_inside (string path, string expected) {
            var resolved = Posix.realpath (path);
            /* A missing file is valid only for shortcuts.vdf; its containing
             * directory was checked separately. */
            return resolved == null || resolved == expected;
        }

        private bool directory_is_expected_or_missing (string path, string expected) {
            var resolved = Posix.realpath (path);
            return resolved == null || resolved == expected;
        }

        private bool is_uint (string value) {
            uint parsed;
            return value != "" && uint.try_parse (value, out parsed);
        }

        private SteamRestartTarget? target_from_json (Json.Object object) {
            SteamInstallationKind kind = SteamInstallationKind.UNKNOWN;
            var data_root = object.get_string_member_with_default ("data_root", "");
            var stored_id = object.get_string_member_with_default ("id", "");
            if (data_root == "" || stored_id == ""
                || !try_installation_kind_from_identifier (object.get_string_member_with_default ("installation_kind", ""), out kind))
                return null;
            var target = new SteamRestartTarget (data_root, kind,
                object.get_string_member_with_default ("display_name", "Steam"),
                optional_string (object, "flatpak_application_id"), optional_string (object, "executable_hint"),
                optional_string (object, "desktop_entry_id"), object.get_boolean_member_with_default ("storage_only", false));
            return target.id == stored_id ? target : null;
        }

        private Json.Object session_to_json (SteamSessionIdentity session) {
            var object = new Json.Object ();
            if (session.boot_id != null)
                object.set_string_member ("boot_id", (!) session.boot_id);
            object.set_int_member ("process_start_ticks", session.process_start_ticks);
            object.set_int_member ("process_pid", session.process_pid);
            if (session.flatpak_instance_id != null)
                object.set_string_member ("flatpak_instance_id", (!) session.flatpak_instance_id);
            return object;
        }

        private SteamSessionIdentity? session_from_json (Json.Object object) {
            var instance = optional_string (object, "flatpak_instance_id");
            var boot = optional_string (object, "boot_id");
            var ticks = object.get_int_member_with_default ("process_start_ticks", 0);
            var pid = object.get_int_member_with_default ("process_pid", 0);
            if (instance != null && instance != "")
                return new SteamSessionIdentity (boot, ticks, (int) pid, instance);
            if (boot == null || boot == "" || ticks <= 0 || pid <= 0 || pid > int.MAX)
                return null;
            return new SteamSessionIdentity (boot, ticks, (int) pid, null);
        }

        private string? optional_string (Json.Object object, string member) {
            if (!object.has_member (member))
                return null;
            var value = object.get_string_member_with_default (member, "");
            return value == "" ? null : value;
        }

        private static string installation_kind_to_identifier (SteamInstallationKind kind) {
            switch (kind) {
            case SteamInstallationKind.NATIVE: return "native";
            case SteamInstallationKind.FLATPAK: return "flatpak";
            case SteamInstallationKind.SNAP: return "snap";
            case SteamInstallationKind.CUSTOM: return "custom";
            default: return "unknown";
            }
        }

        private static bool try_installation_kind_from_identifier (string value, out SteamInstallationKind kind) {
            kind = SteamInstallationKind.UNKNOWN;
            switch (value) {
            case "native": kind = SteamInstallationKind.NATIVE; return true;
            case "flatpak": kind = SteamInstallationKind.FLATPAK; return true;
            case "snap": kind = SteamInstallationKind.SNAP; return true;
            case "custom": kind = SteamInstallationKind.CUSTOM; return true;
            default: return false;
            }
        }
    }
}
