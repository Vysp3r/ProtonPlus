namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    public enum SteamConfigurationMutationResult { FAILED, UNCHANGED, CHANGED, STAGED, PERSISTENCE_FAILED, CONFLICT }
    public class SteamConfigurationMutation : Object {
        public SteamConfigurationMutationResult result { get; private set; }
        public string? error { get; private set; }
        public SteamConfigurationMutation (SteamConfigurationMutationResult result, string? error = null) {
            this.result = result; this.error = error;
        }
        public bool accepted { get { return result == SteamConfigurationMutationResult.UNCHANGED || result == SteamConfigurationMutationResult.CHANGED || result == SteamConfigurationMutationResult.STAGED; } }
    }

    /* The orchestrator depends on this small interface rather than concrete
     * VDF code, which keeps shutdown/relaunch tests host-free. */
    public interface SteamConfigurationReconciler : Object {
        public abstract SteamConfigurationMutation reconcile_target (SteamRestartTarget target);
        public abstract bool verify_target_after_session (SteamRestartTarget target);
    }

    public class SteamConfigurationService : Object, SteamConfigurationReconciler {
        private const string ABSENT = "\u001eprotonplus-absent";
        private SteamSessionService sessions;
        private SteamRestartManager manager;
        private static SteamConfigurationService? configured = null;

        public SteamConfigurationService (SteamSessionService sessions, SteamRestartManager manager) {
            this.sessions = sessions; this.manager = manager;
        }
        public static SteamConfigurationService? instance { get { return configured; } }
        public static void configure (SteamConfigurationService service) { configured = service; }
        public static void reset_configuration () { configured = null; }

        public SteamConfigurationMutation change_default_compatibility_tool (Launchers.Steam steam, string value) {
            return change_compatibility_mapping (steam, 0, value, SteamChangeKind.DEFAULT_COMPATIBILITY_TOOL_CHANGED);
        }
        public SteamConfigurationMutation change_game_compatibility_tool (Games.Steam game, string value) {
            return change_compatibility_mapping ((Launchers.Steam) game.launcher, game.appid, value,
                SteamChangeKind.GAME_COMPATIBILITY_TOOL_CHANGED);
        }
        public SteamConfigurationMutation change_game_launch_options (Games.Steam game, string value, string localconfig_path) {
            var launcher = (Launchers.Steam) game.launcher;
            var target = launcher.get_steam_restart_target ();
            if (target == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "No Steam target.");
            if (game.is_non_steam) {
                if (launcher.profile == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "No Steam profile.");
                var path = Path.build_filename (launcher.profile.userdata_path, "config", "shortcuts.vdf");
                if (!FileUtils.test (path, FileTest.IS_REGULAR)) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "shortcuts.vdf is missing.");
                try {
                    var shortcuts = Utils.VDF.Shortcuts.load (path); var shortcut = shortcuts.get_shortcut_by_appid (game.appid);
                    if (shortcut.AppName == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Shortcut was not found.");
                    return submit (target, SteamChangeKind.NON_STEAM_GAME_LAUNCH_OPTIONS_CHANGED,
                        "%s#shortcut/%u/LaunchOptions".printf (Filename.canonicalize (path, null), game.appid),
                        new SteamConfigurationIntent (SteamConfigurationFile.SHORTCUTS, SteamConfigurationOperation.SHORTCUT_LAUNCH_OPTIONS,
                            Filename.canonicalize (path, null), game.appid.to_string (), shortcut.LaunchOptions,
                            value.replace ("\"", "\\\"")), "");
                } catch (Error e) { return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "shortcuts.vdf could not be parsed."); }
            }
            var content = Utils.Filesystem.get_file_content (localconfig_path);
            var current = launch_value (content, game.appid);
            if (current == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Malformed localconfig.vdf.");
            return submit (target, SteamChangeKind.STEAM_GAME_LAUNCH_OPTIONS_CHANGED,
                "%s#%s/LaunchOptions".printf (Filename.canonicalize (localconfig_path, null), game.appid.to_string ()),
                new SteamConfigurationIntent (SteamConfigurationFile.LOCALCONFIG, SteamConfigurationOperation.LAUNCH_OPTIONS,
                    Filename.canonicalize (localconfig_path, null), game.appid.to_string (), (!) current,
                    value == "" ? ABSENT : value), content);
        }

        private SteamConfigurationMutation change_compatibility_mapping (Launchers.Steam steam, uint appid, string value, SteamChangeKind kind) {
            var target = steam.get_steam_restart_target ();
            if (target == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "No Steam target.");
            var path = Path.build_filename (steam.directory, "config", "config.vdf");
            var content = Utils.Filesystem.get_file_content (path);
            var current = compatibility_value (content, appid);
            if (current == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Malformed config.vdf.");
            var desired = appid != 0 && value == "Default" ? ABSENT : value;
            return submit (target, kind, "%s#CompatToolMapping/%u".printf (Filename.canonicalize (path, null), appid),
                new SteamConfigurationIntent (SteamConfigurationFile.CONFIG, SteamConfigurationOperation.COMPATIBILITY_MAPPING,
                    Filename.canonicalize (path, null), appid.to_string (), (!) current, desired), content);
        }

        private SteamConfigurationMutation submit (SteamRestartTarget target, SteamChangeKind kind, string key,
            SteamConfigurationIntent intent, string content) {
            if (intent.baseline == intent.desired)
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.UNCHANGED);
            var snapshot = sessions.inspect (target);
            if (snapshot.state == SteamSessionState.STOPPED && snapshot.state_confidence == SteamEvidenceLevel.CONFIRMED) {
                var changed = apply_intent (intent, content, true);
                return new SteamConfigurationMutation (changed ? SteamConfigurationMutationResult.CHANGED : SteamConfigurationMutationResult.FAILED);
            }
            var receipt = new SteamChangeReceipt (target, kind, SteamRestartRequirement.CONSERVATIVE, key, intent.field_id, null, null, intent);
            var recorded = manager.record (receipt);
            if (recorded == SteamRestartRecordResult.PERSISTENCE_FAILED)
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.PERSISTENCE_FAILED, manager.last_persistence_error);
            if (recorded == SteamRestartRecordResult.REQUIREMENT_CLEARED)
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.UNCHANGED);
            return new SteamConfigurationMutation (SteamConfigurationMutationResult.STAGED);
        }

        public SteamConfigurationMutation reconcile_target (SteamRestartTarget target) {
            var aggregate = SteamConfigurationMutationResult.UNCHANGED;
            foreach (var record in manager.get_pending_changes_for_target (target)) {
                var intent = record.receipt.configuration_intent;
                if (intent == null) continue;
                var content = Utils.Filesystem.get_file_content (intent.path);
                var current = value_for_intent ((!) intent, content);
                if (current == null)
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Configuration file could not be parsed.");
                if (current == ((!) intent).desired) continue;
                if (current != ((!) intent).baseline)
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.CONFLICT, "The targeted Steam setting changed externally.");
                if (!apply_intent ((!) intent, content, true))
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Unable to apply a pending Steam setting.");
                aggregate = SteamConfigurationMutationResult.CHANGED;
            }
            return new SteamConfigurationMutation (aggregate);
        }

        public bool verify_target_after_session (SteamRestartTarget target) {
            var all = true;
            foreach (var record in manager.get_pending_changes_for_target (target)) {
                var intent = record.receipt.configuration_intent;
                if (intent == null) continue;
                var current = value_for_intent ((!) intent, Utils.Filesystem.get_file_content (((!) intent).path));
                if (current != ((!) intent).desired || !manager.clear_verified_configuration (record)) all = false;
            }
            return all;
        }

        private string? value_for_intent (SteamConfigurationIntent intent, string content) {
            switch (intent.operation) {
            case SteamConfigurationOperation.COMPATIBILITY_MAPPING:
                uint appid; if (!uint.try_parse (intent.field_id, out appid)) return null;
                return compatibility_value (content, appid);
            case SteamConfigurationOperation.LAUNCH_OPTIONS:
                uint appid; if (!uint.try_parse (intent.field_id, out appid)) return null;
                return launch_value (content, appid);
            case SteamConfigurationOperation.SHORTCUT_LAUNCH_OPTIONS:
                uint shortcut_id; if (!uint.try_parse (intent.field_id, out shortcut_id)) return null;
                try { return Utils.VDF.Shortcuts.load (intent.path).get_shortcut_by_appid (shortcut_id).LaunchOptions; } catch (Error e) { return null; }
            default: return null;
            }
        }
        private bool apply_intent (SteamConfigurationIntent intent, string content, bool write) {
            string? modified = null;
            switch (intent.operation) {
            case SteamConfigurationOperation.COMPATIBILITY_MAPPING:
                uint appid; if (!uint.try_parse (intent.field_id, out appid)) return false;
                modified = mutate_compatibility (content, appid, intent.desired); break;
            case SteamConfigurationOperation.LAUNCH_OPTIONS:
                uint appid; if (!uint.try_parse (intent.field_id, out appid)) return false;
                modified = mutate_launch (content, appid, intent.desired); break;
            case SteamConfigurationOperation.SHORTCUT_LAUNCH_OPTIONS:
                uint shortcut_id; if (!uint.try_parse (intent.field_id, out shortcut_id)) return false;
                try {
                    var shortcuts = Utils.VDF.Shortcuts.load (intent.path); var shortcut = shortcuts.get_shortcut_by_appid (shortcut_id);
                    if (shortcut.AppName == null) return false;
                    shortcut.LaunchOptions = intent.desired;
                    if (!shortcuts.replace_shortcut_by_appid (shortcut_id, shortcut)) return false;
                    if (write) shortcuts.save ();
                    return true;
                } catch (Error e) { return false; }
            default: return false;
            }
            return modified != null && (!write || Utils.Filesystem.modify_file (intent.path, (!) modified));
        }

        private string? compatibility_value (string content, uint appid) {
            var doc = Utils.VDF.VdfParser.parse_document (content); if (doc == null) return null;
            var root = doc.root.get_child ("InstallConfigStore"); var software = root != null ? root.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null; var steam = valve != null ? valve.get_child ("Steam") : null;
            var mapping = steam != null ? steam.get_child ("CompatToolMapping") : null; var entry = mapping != null ? mapping.get_child (appid.to_string ()) : null;
            var name = entry != null ? entry.get_child ("name") : null;
            return name != null && name.value != null ? name.value : ABSENT;
        }
        private string? launch_value (string content, uint appid) {
            var doc = Utils.VDF.VdfParser.parse_document (content); if (doc == null) return null;
            var root = doc.root.get_child ("UserLocalConfigStore"); var software = root != null ? root.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null; var steam = valve != null ? valve.get_child ("Steam") : null;
            var apps = steam != null ? steam.get_child ("apps") : null; var app = apps != null ? apps.get_child (appid.to_string ()) : null;
            if (app == null) return null;
            var field = app.get_child ("LaunchOptions"); return field != null && field.value != null ? field.value : ABSENT;
        }
        private string? mutate_compatibility (string content, uint appid, string desired) {
            var doc = Utils.VDF.VdfParser.parse_document (content); if (doc == null) return null;
            var root = doc.root.get_child ("InstallConfigStore"); var software = root != null ? root.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null; var steam = valve != null ? valve.get_child ("Steam") : null;
            if (steam == null || steam.closing_brace_start == -1) return null;
            var mapping = steam.get_child ("CompatToolMapping");
            if (mapping == null && desired != ABSENT) {
                var i = doc.indentation_of_closing_brace (steam); var expanded = doc.insert_before_closing_brace (steam, "%s\"CompatToolMapping\"\n%s{\n%s}\n".printf (i + "\t", i + "\t", i + "\t"));
                doc = Utils.VDF.VdfParser.parse_document (expanded); if (doc == null) return null;
                root = doc.root.get_child ("InstallConfigStore"); software = root != null ? root.get_child ("Software") : null; valve = software != null ? software.get_child ("Valve") : null; steam = valve != null ? valve.get_child ("Steam") : null; mapping = steam != null ? steam.get_child ("CompatToolMapping") : null;
            }
            if (mapping == null) return content;
            var entry = mapping.get_child (appid.to_string ());
            if (desired == ABSENT) return entry != null ? doc.remove_entry (entry) : content;
            if (entry != null) { var name = entry.get_child ("name"); return name != null ? doc.replace_value (name, desired) : null; }
            var i = doc.indentation_of_closing_brace (mapping); var e = i + "\t";
            return doc.insert_before_closing_brace (mapping, "%s\"%u\"\n%s{\n%s\t\"name\"\t\t%s\n%s\t\"config\"\t\t\"\"\n%s\t\"priority\"\t\t\"%s\"\n%s}\n".printf (e, appid, e, e, Utils.VDF.VdfDocument.quote (desired), e, e, appid == 0 ? "75" : "250", e));
        }
        private string? mutate_launch (string content, uint appid, string desired) {
            var doc = Utils.VDF.VdfParser.parse_document (content); if (doc == null) return null;
            var root = doc.root.get_child ("UserLocalConfigStore"); var software = root != null ? root.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null; var steam = valve != null ? valve.get_child ("Steam") : null; var apps = steam != null ? steam.get_child ("apps") : null; var app = apps != null ? apps.get_child (appid.to_string ()) : null;
            if (app == null || app.closing_brace_start == -1) return null; var field = app.get_child ("LaunchOptions");
            if (desired == ABSENT) return field != null ? doc.remove_entry (field) : content;
            if (field != null) return doc.replace_value (field, desired);
            var i = doc.indentation_of_closing_brace (app) + "\t"; return doc.insert_before_closing_brace (app, "%s\"LaunchOptions\"\t\t%s\n".printf (i, Utils.VDF.VdfDocument.quote (desired)));
        }
    }
}
