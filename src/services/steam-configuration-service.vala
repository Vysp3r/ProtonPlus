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

    /* Keep the environment-dependent ProtonPlus shortcut construction at the
     * edge of the configuration service.  Production still uses Shortcuts,
     * while lifecycle tests can exercise the service without a bundled icon,
     * installed executable, or desktop session. */
    public interface SteamShortcutMutator : Object {
        public abstract bool install (Utils.VDF.Shortcuts shortcuts);
        public abstract bool remove (Utils.VDF.Shortcuts shortcuts);
    }

    private class DefaultSteamShortcutMutator : Object, SteamShortcutMutator {
        public bool install (Utils.VDF.Shortcuts shortcuts) {
            return shortcuts.install_for_current_environment ();
        }
        public bool remove (Utils.VDF.Shortcuts shortcuts) {
            return shortcuts.uninstall ();
        }
    }

    public class SteamConfigurationService : Object, SteamConfigurationReconciler {
        private const string ABSENT = "\u001eprotonplus-absent";
        private SteamSessionService sessions;
        private SteamRestartManager manager;
        private SteamShortcutMutator shortcut_mutator;
        private static SteamConfigurationService? configured = null;

        public SteamConfigurationService (SteamSessionService sessions, SteamRestartManager manager,
            SteamShortcutMutator? shortcut_mutator = null) {
            this.sessions = sessions;
            this.manager = manager;
            this.shortcut_mutator = shortcut_mutator ?? new DefaultSteamShortcutMutator ();
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
            if (!FileUtils.test (localconfig_path, FileTest.IS_REGULAR))
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "localconfig.vdf is missing.");
            var content = Utils.Filesystem.get_file_content (localconfig_path);
            var current = launch_value (content, game.appid);
            if (current == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Malformed localconfig.vdf.");
            return submit (target, SteamChangeKind.STEAM_GAME_LAUNCH_OPTIONS_CHANGED,
                "%s#%s/LaunchOptions".printf (Filename.canonicalize (localconfig_path, null), game.appid.to_string ()),
                new SteamConfigurationIntent (SteamConfigurationFile.LOCALCONFIG, SteamConfigurationOperation.LAUNCH_OPTIONS,
                    Filename.canonicalize (localconfig_path, null), game.appid.to_string (), (!) current,
                    value, current != ABSENT, value != ""), content);
        }

        public bool protonplus_shortcut_is_effectively_installed (SteamProfile profile) {
            var target = profile.launcher.get_steam_restart_target ();
            if (target == null) return profile.shortcuts != null && ((!) profile.shortcuts).get_installed_status ();
            var path = Filename.canonicalize (Path.build_filename (profile.userdata_path, "config", "shortcuts.vdf"), null);
            var intent = manager.get_pending_configuration_intent (target, "%s#ProtonPlus".printf (path));
            if (intent != null)
                return ((!) intent).desired_present;
            return profile.shortcuts != null && ((!) profile.shortcuts).get_installed_status ();
        }

        /* Loading Steam data must never write Steam-owned files.  These
         * overlays make persisted, accepted intent visible after ProtonPlus
         * restarts while leaving the on-disk baseline untouched. */
        public void overlay_launcher_effective_state (Launchers.Steam launcher) {
            var target = launcher.get_steam_restart_target ();
            if (target == null || launcher.compatibility_tool_hashtable == null) return;
            foreach (var record in manager.get_pending_changes_for_target (target)) {
                var intent = record.receipt.configuration_intent;
                if (intent == null || ((!) intent).operation != SteamConfigurationOperation.COMPATIBILITY_MAPPING) continue;
                uint appid;
                if (!uint.try_parse (((!) intent).field_id, out appid)) continue;
                var value = ((!) intent).desired_present ? ((!) intent).desired : (appid == 0 ? "proton_experimental" : "Default");
                if (appid == 0) {
                    launcher.compatibility_tool_hashtable.set (appid, value);
                    launcher.default_compatibility_tool = value;
                } else {
                    launcher.update_game_compatibility_tool_mapping (appid, value);
                }
                foreach (var game in (List<Games.Steam>) launcher.games) {
                    if (game.appid == appid) game.apply_effective_compatibility_tool (value);
                }
            }
        }

        public void overlay_profile_effective_state (SteamProfile profile) {
            var target = profile.launcher.get_steam_restart_target ();
            if (target == null || profile.launch_options_hashtable == null) return;
            var localconfig = Filename.canonicalize (profile.localconfig_path, null);
            var shortcuts = Filename.canonicalize (Path.build_filename (profile.userdata_path, "config", "shortcuts.vdf"), null);
            foreach (var record in manager.get_pending_changes_for_target (target)) {
                var intent = record.receipt.configuration_intent;
                if (intent == null) continue;
                uint appid;
                if (!uint.try_parse (((!) intent).field_id, out appid)) continue;
                var value = ((!) intent).desired_present ? ((!) intent).desired : "";
                if (((!) intent).path == localconfig
                    && ((!) intent).operation == SteamConfigurationOperation.LAUNCH_OPTIONS) {
                    profile.launch_options_hashtable.set (appid, value);
                    foreach (var game in (List<Games.Steam>) profile.launcher.games) {
                        if (game.appid == appid) game.launch_options = value;
                    }
                } else if (((!) intent).path == shortcuts
                    && ((!) intent).operation == SteamConfigurationOperation.SHORTCUT_LAUNCH_OPTIONS
                    && profile.non_steam_games != null) {
                    /* Binary VDF stores escaped quotes; the game model owns
                     * the user-facing, unescaped command spelling. */
                    var displayed = value.replace ("\\\"", "\"");
                    foreach (var game in profile.non_steam_games) {
                        if (game.appid == appid) game.launch_options = displayed;
                    }
                }
            }
        }

        public async SteamConfigurationMutation install_protonplus_shortcut (SteamProfile profile) {
            return change_protonplus_shortcut (profile, true);
        }

        public async SteamConfigurationMutation remove_protonplus_shortcut (SteamProfile profile) {
            return change_protonplus_shortcut (profile, false);
        }

        private SteamConfigurationMutation change_protonplus_shortcut (SteamProfile profile, bool desired_present) {
            var target = profile.launcher.get_steam_restart_target ();
            if (target == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "No Steam target.");
            var path = Filename.canonicalize (Path.build_filename (profile.userdata_path, "config", "shortcuts.vdf"), null);
            var installed = profile.shortcuts != null && ((!) profile.shortcuts).get_installed_status ();
            var existing = manager.get_pending_configuration_intent (target, "%s#ProtonPlus".printf (path));
            if (existing != null && ((!) existing).desired_present == desired_present)
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.UNCHANGED);
            if (existing == null && installed == desired_present)
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.UNCHANGED);

            var snapshot = sessions.inspect (target);
            if (snapshot.state == SteamSessionState.STOPPED && snapshot.state_confidence == SteamEvidenceLevel.CONFIRMED) {
                try {
                    var shortcuts = FileUtils.test (path, FileTest.IS_REGULAR)
                        ? Utils.VDF.Shortcuts.load (path) : Utils.VDF.Shortcuts.empty (path);
                    var changed = desired_present ? shortcut_mutator.install (shortcuts) : shortcut_mutator.remove (shortcuts);
                    if (!changed) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Unable to change ProtonPlus shortcut.");
                    profile.shortcuts = shortcuts;
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.CHANGED);
                } catch (Error e) {
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Unable to change ProtonPlus shortcut.");
                }
            }

            /* Shortcut presence is a single replayable operation.  During
             * reconciliation it creates a missing file only when creation is
             * still desired; reverting before that point cannot leave an
             * orphan file-creation receipt or create an empty VDF. */
            var intent = new SteamConfigurationIntent (SteamConfigurationFile.SHORTCUTS,
                SteamConfigurationOperation.SHORTCUT_PRESENCE, path, "ProtonPlus",
                installed ? "present" : "", desired_present ? "present" : "",
                installed, desired_present);
            return record_intent (target, desired_present ? SteamChangeKind.PROTONPLUS_SHORTCUT_CREATED
                : SteamChangeKind.PROTONPLUS_SHORTCUT_REMOVED, "%s#ProtonPlus".printf (path), intent);
        }

        private SteamConfigurationMutation record_intent (SteamRestartTarget target, SteamChangeKind kind,
            string key, SteamConfigurationIntent intent) {
            var result = manager.record (new SteamChangeReceipt (target, kind, SteamRestartRequirement.CONSERVATIVE,
                key, intent.field_id, null, null, intent));
            if (result == SteamRestartRecordResult.PERSISTENCE_FAILED)
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.PERSISTENCE_FAILED, manager.last_persistence_error);
            if (result == SteamRestartRecordResult.REQUIREMENT_CLEARED)
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.UNCHANGED);
            return new SteamConfigurationMutation (SteamConfigurationMutationResult.STAGED);
        }

        private SteamConfigurationMutation change_compatibility_mapping (Launchers.Steam steam, uint appid, string value, SteamChangeKind kind) {
            var target = steam.get_steam_restart_target ();
            if (target == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "No Steam target.");
            var path = Path.build_filename (steam.directory, "config", "config.vdf");
            if (!FileUtils.test (path, FileTest.IS_REGULAR))
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "config.vdf is missing.");
            var content = Utils.Filesystem.get_file_content (path);
            var current = compatibility_value (content, appid);
            if (current == null) return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Malformed config.vdf.");
            var desired_absent = appid != 0 && value == "Default";
            var desired = desired_absent ? "" : value;
            return submit (target, kind, "%s#CompatToolMapping/%u".printf (Filename.canonicalize (path, null), appid),
                new SteamConfigurationIntent (SteamConfigurationFile.CONFIG, SteamConfigurationOperation.COMPATIBILITY_MAPPING,
                    Filename.canonicalize (path, null), appid.to_string (), current == ABSENT ? "" : (!) current, desired,
                    current != ABSENT, !desired_absent), content);
        }

        private SteamConfigurationMutation submit (SteamRestartTarget target, SteamChangeKind kind, string key,
            SteamConfigurationIntent intent, string content) {
            var existing = manager.get_pending_configuration_intent (target, key);
            if (existing != null && same_desired ((!) existing, intent))
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.UNCHANGED);
            if (existing == null && intent.baseline_present == intent.desired_present
                && intent.baseline == intent.desired)
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
            var snapshot = sessions.inspect (target);
            if (snapshot.state != SteamSessionState.STOPPED
                || snapshot.state_confidence != SteamEvidenceLevel.CONFIRMED)
                return new SteamConfigurationMutation (SteamConfigurationMutationResult.STAGED,
                    "Steam has not been confirmed stopped.");
            var aggregate = SteamConfigurationMutationResult.UNCHANGED;
            var records = manager.get_pending_changes_for_target (target);
            /* A prerequisite is always processed before a shortcut mutation;
             * Hash-map iteration order is not a persistence contract. */
            foreach (var record in records) {
                var intent = record.receipt.configuration_intent;
                if (intent == null || ((!) intent).operation != SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT) continue;
                if (!apply_pending_intent ((!) intent))
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Unable to create shortcuts.vdf.");
                aggregate = SteamConfigurationMutationResult.CHANGED;
            }
            foreach (var record in records) {
                var intent = record.receipt.configuration_intent;
                if (intent == null) continue;
                if (((!) intent).operation == SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT) continue;
                if (!FileUtils.test (((!) intent).path, FileTest.IS_REGULAR))
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Configuration file is missing.");
                var content = intent.file == SteamConfigurationFile.SHORTCUTS
                    ? "" : Utils.Filesystem.get_file_content (intent.path);
                var current = value_for_intent ((!) intent, content);
                if (current == null)
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Configuration file could not be parsed.");
                if (matches_desired ((!) intent, current)) continue;
                if (!matches_baseline ((!) intent, current))
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.CONFLICT, "The targeted Steam setting changed externally.");
                if (!apply_intent ((!) intent, content, true))
                    return new SteamConfigurationMutation (SteamConfigurationMutationResult.FAILED, "Unable to apply a pending Steam setting.");
                aggregate = SteamConfigurationMutationResult.CHANGED;
            }
            return new SteamConfigurationMutation (aggregate);
        }

        public bool verify_target_after_session (SteamRestartTarget target) {
            var verified = new Gee.ArrayList<SteamRestartPendingRecord> ();
            foreach (var record in manager.get_pending_changes_for_target (target)) {
                var intent = record.receipt.configuration_intent;
                if (intent == null) continue;
                if (!FileUtils.test (((!) intent).path, FileTest.IS_REGULAR))
                    return false;
                var content = ((!) intent).file == SteamConfigurationFile.SHORTCUTS
                    ? "" : Utils.Filesystem.get_file_content (((!) intent).path);
                var current = value_for_intent ((!) intent, content);
                if (!matches_desired ((!) intent, current))
                    return false;
                verified.add (record);
            }
            return manager.clear_verified_configurations (verified);
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
            case SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT:
                return FileUtils.test (intent.path, FileTest.IS_REGULAR) ? "present" : ABSENT;
            case SteamConfigurationOperation.SHORTCUT_PRESENCE:
                try { return Utils.VDF.Shortcuts.load (intent.path).get_installed_status () ? "present" : ABSENT; }
                catch (Error e) { return FileUtils.test (intent.path, FileTest.EXISTS) ? null : ABSENT; }
            default: return null;
            }
        }
        private bool apply_intent (SteamConfigurationIntent intent, string content, bool write) {
            string? modified = null;
            switch (intent.operation) {
            case SteamConfigurationOperation.COMPATIBILITY_MAPPING:
                uint appid; if (!uint.try_parse (intent.field_id, out appid)) return false;
                modified = mutate_compatibility (content, appid, intent.desired, intent.desired_present); break;
            case SteamConfigurationOperation.LAUNCH_OPTIONS:
                uint appid; if (!uint.try_parse (intent.field_id, out appid)) return false;
                modified = mutate_launch (content, appid, intent.desired, intent.desired_present); break;
            case SteamConfigurationOperation.SHORTCUT_LAUNCH_OPTIONS:
                uint shortcut_id; if (!uint.try_parse (intent.field_id, out shortcut_id)) return false;
                try {
                    var shortcuts = Utils.VDF.Shortcuts.load (intent.path); var shortcut = shortcuts.get_shortcut_by_appid (shortcut_id);
                    if (shortcut.AppName == null) return false;
                    if (!intent.desired_present) return false;
                    shortcut.LaunchOptions = intent.desired;
                    if (!shortcuts.replace_shortcut_by_appid (shortcut_id, shortcut)) return false;
                    if (write) shortcuts.save ();
                    return true;
                } catch (Error e) { return false; }
            case SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT:
            case SteamConfigurationOperation.SHORTCUT_PRESENCE:
                return apply_pending_intent (intent);
            default: return false;
            }
            return modified != null && (!write || Utils.Filesystem.modify_file (intent.path, (!) modified));
        }

        private bool apply_pending_intent (SteamConfigurationIntent intent) {
            if (intent.operation == SteamConfigurationOperation.SHORTCUTS_FILE_PRESENT) {
                if (FileUtils.test (intent.path, FileTest.IS_REGULAR)) return true;
                try { Utils.VDF.Shortcuts.empty (intent.path).save (); return true; } catch (Error e) { return false; }
            }
            if (intent.operation == SteamConfigurationOperation.SHORTCUT_PRESENCE) {
                try {
                    var shortcuts = FileUtils.test (intent.path, FileTest.IS_REGULAR)
                        ? Utils.VDF.Shortcuts.load (intent.path) : Utils.VDF.Shortcuts.empty (intent.path);
                    if (intent.desired_present)
                        return shortcuts.get_installed_status () || shortcut_mutator.install (shortcuts);
                    return !shortcuts.get_installed_status () || shortcut_mutator.remove (shortcuts);
                } catch (Error e) { return false; }
            }
            return apply_intent (intent, Utils.Filesystem.get_file_content (intent.path), true);
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
        private bool same_desired (SteamConfigurationIntent first, SteamConfigurationIntent second) {
            return first.desired_present == second.desired_present && first.desired == second.desired;
        }

        private bool matches_desired (SteamConfigurationIntent intent, string? value) {
            return value != null && (value == ABSENT
                ? !intent.desired_present : intent.desired_present && value == intent.desired);
        }

        private bool matches_baseline (SteamConfigurationIntent intent, string? value) {
            if (value == null) return false;
            var present = value != ABSENT;
            if (intent.baseline != "" || !intent.baseline_present)
                return present == intent.baseline_present && (!present || value == intent.baseline);
            return SteamConfigurationIntent.fingerprint (present ? value : "", present) == intent.baseline_fingerprint;
        }

        private string? mutate_compatibility (string content, uint appid, string desired, bool desired_present) {
            var doc = Utils.VDF.VdfParser.parse_document (content); if (doc == null) return null;
            var root = doc.root.get_child ("InstallConfigStore"); var software = root != null ? root.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null; var steam = valve != null ? valve.get_child ("Steam") : null;
            if (steam == null || steam.closing_brace_start == -1) return null;
            var mapping = steam.get_child ("CompatToolMapping");
            if (mapping == null && desired_present) {
                var i = doc.indentation_of_closing_brace (steam); var expanded = doc.insert_before_closing_brace (steam, "%s\"CompatToolMapping\"\n%s{\n%s}\n".printf (i + "\t", i + "\t", i + "\t"));
                doc = Utils.VDF.VdfParser.parse_document (expanded); if (doc == null) return null;
                root = doc.root.get_child ("InstallConfigStore"); software = root != null ? root.get_child ("Software") : null; valve = software != null ? software.get_child ("Valve") : null; steam = valve != null ? valve.get_child ("Steam") : null; mapping = steam != null ? steam.get_child ("CompatToolMapping") : null;
            }
            if (mapping == null) return content;
            var entry = mapping.get_child (appid.to_string ());
            if (!desired_present) return entry != null ? doc.remove_entry (entry) : content;
            if (entry != null) { var name = entry.get_child ("name"); return name != null ? doc.replace_value (name, desired) : null; }
            var i = doc.indentation_of_closing_brace (mapping); var e = i + "\t";
            return doc.insert_before_closing_brace (mapping, "%s\"%u\"\n%s{\n%s\t\"name\"\t\t%s\n%s\t\"config\"\t\t\"\"\n%s\t\"priority\"\t\t\"%s\"\n%s}\n".printf (e, appid, e, e, Utils.VDF.VdfDocument.quote (desired), e, e, appid == 0 ? "75" : "250", e));
        }
        private string? mutate_launch (string content, uint appid, string desired, bool desired_present) {
            var doc = Utils.VDF.VdfParser.parse_document (content); if (doc == null) return null;
            var root = doc.root.get_child ("UserLocalConfigStore"); var software = root != null ? root.get_child ("Software") : null;
            var valve = software != null ? software.get_child ("Valve") : null; var steam = valve != null ? valve.get_child ("Steam") : null; var apps = steam != null ? steam.get_child ("apps") : null; var app = apps != null ? apps.get_child (appid.to_string ()) : null;
            if (app == null || app.closing_brace_start == -1) return null; var field = app.get_child ("LaunchOptions");
            if (!desired_present) return field != null ? doc.remove_entry (field) : content;
            if (field != null) return doc.replace_value (field, desired);
            var i = doc.indentation_of_closing_brace (app) + "\t"; return doc.insert_before_closing_brace (app, "%s\"LaunchOptions\"\t\t%s\n".printf (i, Utils.VDF.VdfDocument.quote (desired)));
        }
    }
}
