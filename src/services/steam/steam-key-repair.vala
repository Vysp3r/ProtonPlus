namespace ProtonPlus.Services {
    using ProtonPlus.Models;
    using ProtonPlus.Utils.VDF;

    internal delegate void SteamKeyRepairOperation () throws Error;

    public class SteamKeyRepairSlot : Object {
        public string path;
        public string title;
        public string key;
        public bool macos_only;
        public string replacement = "";
        public string manifest = "";
        public string metadata = "";

        public SteamKeyRepairSlot (CompatibilityTool claim) {
            path = Posix.realpath (claim.inspection_path) ?? claim.inspection_path;
            title = claim.display_title;
            key = claim.internal_title;
            macos_only = claim.macos_only;
        }
    }

    public class SteamKeyRepairPreview : Object {
        public Gee.ArrayList<SteamKeyRepairSlot> claims = new Gee.ArrayList<SteamKeyRepairSlot> ();
        public Gee.List<SteamRestartPendingRecord> pending;
        public HashTable<uint, string> mappings;
        public string config;
        public bool recovery_available;
        public string token;

        public SteamKeyRepairPreview (string config, Gee.List<SteamRestartPendingRecord> pending) throws Error {
            this.config = config;
            this.pending = pending;
            mappings = SteamConfigurationService.read_repair_mappings (config);
        }

        public bool affects (SteamConfigurationIntent intent, string key) {
            uint appid;
            return intent.operation == SteamConfigurationOperation.COMPATIBILITY_MAPPING
                && ((uint.try_parse (intent.field_id, out appid) && mappings.get (appid) == key)
                    || intent.matches_baseline (key, true)
                    || (intent.desired_present && intent.desired == key));
        }
    }

    public class SteamKeyRepair : Object {
        internal const string JOURNAL = ".protonplus-steam-key-repair";
        private Launchers.Steam steam;
        private SteamRestartTarget target;
        private SteamSessionService sessions;
        private SteamRestartManager manager;
        private SteamConfigurationService configuration;
        private string root;
        private string config_path;
        private string journal_path;

        public SteamKeyRepair (Launchers.Steam steam, SteamSessionService sessions,
            SteamRestartManager manager, SteamConfigurationService configuration) throws Error {
            this.steam = steam;
            this.sessions = sessions;
            this.manager = manager;
            this.configuration = configuration;
            var restart_target = steam.get_steam_restart_target ();
            if (restart_target == null)
                throw new IOError.NOT_FOUND (_ ("No Steam target was found."));
            target = restart_target;
            var managed_root = steam.get_managed_compatibility_tools_root ();
            root = Posix.realpath (managed_root) ?? managed_root;
            config_path = Path.build_filename (target.data_root, "config", "config.vdf");
            journal_path = Path.build_filename (root, JOURNAL);
        }

        public SteamKeyRepairPreview preview () throws Error {
            var stored = manager.read_persisted_changes ();
            if (stored.error != null)
                throw new IOError.INVALID_DATA (stored.error);
            var pending = new Gee.ArrayList<SteamRestartPendingRecord> ();
            foreach (var record in stored.records) {
                if (record.receipt.target.id == target.id)
                    pending.add (record);
            }
            var preview = new SteamKeyRepairPreview (Utils.Filesystem.read_regular_text (config_path), pending);
            preview.recovery_available = FileUtils.test (journal_path, FileTest.EXISTS | FileTest.IS_SYMLINK);
            var ownership = new Gee.HashMap<string, SteamKeyRepairSlot> ();
            foreach (var group in steam.groups) {
                var inventory = group.installed_tool_inventory;
                inventory.refresh (false);
                foreach (var entry in inventory.get_snapshot ()) {
                    var provider = inventory.get_provider_tool_for_entry (entry);
                    if (provider == null || !inventory.is_latest_installation (entry, provider))
                        continue;
                    var variant = inventory.get_latest_variant (entry, provider);
                    if (variant == null)
                        continue;
                    var path = Posix.realpath (entry.path) ?? entry.path;
                    if (Path.get_dirname (path) != root)
                        continue;
                    var found = CompatibilityToolLoader.read_claims (path, path, false);
                    if (found.size != 1 || found[0].internal_title != entry.internal_title)
                        continue;
                    var slot = new SteamKeyRepairSlot (found[0]);
                    try {
                        slot.metadata = Utils.Filesystem.read_regular_text (Path.build_filename (path, Utils.Metadata.FILENAME));
                        slot.manifest = Utils.Filesystem.read_regular_text (manifest_path (path));
                    } catch (Error e) {
                        continue;
                    }
                    slot.replacement = StandardArchiveWorkflow.latest_steam_key (provider, variant,
                        provider.definition.managed_steam_manifest);
                    ownership.set (path, slot);
                }
            }
            foreach (var claim in steam.scan_compatibility_tool_claims ()) {
                var slot = new SteamKeyRepairSlot (claim);
                var owned_slot = ownership.get (slot.path);
                preview.claims.add (!claim.externally_managed && owned_slot != null && owned_slot.key == slot.key
                    ? owned_slot : slot);
            }
            preview.claims.sort ((a, b) => {
                var order = strcmp (a.key, b.key);
                return order == 0 ? strcmp (a.path, b.path) : order;
            });
            var fingerprint = new KeyFile ();
            fingerprint.set_string ("target", "id", target.id);
            fingerprint.set_string ("target", "config", preview.config);
            for (var i = 0; i < preview.claims.size; i++) {
                var slot = preview.claims[i];
                var section = i.to_string ();
                fingerprint.set_string (section, "path", slot.path);
                fingerprint.set_string (section, "key", slot.key);
                fingerprint.set_string (section, "replacement", slot.replacement);
                fingerprint.set_string (section, "manifest", slot.manifest);
                fingerprint.set_string (section, "metadata", slot.metadata);
            }
            preview.token = Checksum.compute_for_string (ChecksumType.SHA256, fingerprint.to_data ());
            return preview;
        }

        public void apply (string token, string key, string retain, Gee.Map<string, string> assignments) throws Error {
            InstallationService.instance.run_steam_key_repair (root, () => {
                manager.with_configuration_lock (() => {
                    require_stopped ();
                    var current = preview ();
                    if (current.recovery_available)
                        throw new IOError.BUSY (_ ("An interrupted repair must be resumed first."));
                    if (current.token != token)
                        throw new IOError.BUSY (_ ("Steam tool claims or mappings changed. Preview the repair again."));
                    var plan = make_plan (current, key, retain, assignments);
                    if (Utils.Filesystem.read_regular_text (config_path) != current.config)
                        throw new IOError.BUSY (_ ("Steam config.vdf changed since the repair was planned."));
                    validate_plan (plan, current);
                    require_stopped ();
                    Utils.Filesystem.replace_text_durably (journal_path, plan.to_data ());
                    finish (plan);
                });
            });
        }

        public void resume () throws Error {
            InstallationService.instance.run_steam_key_repair (root, () => {
                manager.with_configuration_lock (() => {
                    require_stopped ();
                    var plan = new KeyFile ();
                    plan.load_from_data (Utils.Filesystem.read_regular_text (journal_path), -1, KeyFileFlags.NONE);
                    finish (plan);
                });
            });
        }

        public string? owner_conflict (SteamKeyRepairPreview preview, string key, string directory) {
            try {
                var plan = make_plan (preview, key, directory, new Gee.HashMap<string, string> ());
                validate_plan (plan, preview);
                return null;
            } catch (Error e) {
                return e.message;
            }
        }

        private KeyFile make_plan (SteamKeyRepairPreview current, string key, string retain,
            Gee.Map<string, string> assignments) throws Error {
            var plan = new KeyFile ();
            plan.set_integer ("repair", "version", 1);
            plan.set_string ("repair", "target", target.id);
            plan.set_string ("repair", "key", key);
            plan.set_string ("repair", "config-before", current.config);
            var claimed = new Gee.HashSet<string> ();
            var replacements = new Gee.HashMap<string, SteamKeyRepairSlot> ();
            var dirs = new Gee.ArrayList<string> ();
            foreach (var slot in current.claims)
                claimed.add (slot.key.ascii_down ());
            var found_owner = false;
            foreach (var slot in current.claims) {
                if (slot.key.ascii_down () != key.ascii_down ())
                    continue;
                if (slot.key != key || slot.replacement == "")
                    throw new IOError.INVALID_DATA (_ ("Ownership of a tool claiming the historical key is uncertain."));
                var dir = Path.get_basename (slot.path);
                var retained = dir == retain;
                found_owner |= retained;
                if (!retained && !claimed.add (slot.replacement.ascii_down ()))
                    throw new IOError.EXISTS (_ ("The replacement Steam key is already claimed: %s").printf (slot.replacement));
                var document = VdfParser.parse_document (slot.manifest);
                var definitions = document == null ? null : CompatibilityToolLoader.find_compat_tools (document);
                if (definitions == null || definitions.children.size != 1 || definitions.children[0].key != key)
                    throw new IOError.INVALID_DATA (_ ("A compatibility tool manifest could not be rewritten."));
                var replacement = retained ? key : slot.replacement;
                if (!retained)
                    replacements.set (dir, slot);
                dirs.add (dir);
                var section = "slot:" + (dirs.size - 1).to_string ();
                plan.set_string (section, "before", slot.manifest);
                plan.set_string (section, "after", retained ? slot.manifest : document.replace_key (definitions.children[0], replacement));
                plan.set_string (section, "metadata", slot.metadata);
                plan.set_string (section, "replacement", replacement);
            }
            if (dirs.size < 2 || !found_owner)
                throw new IOError.INVALID_ARGUMENT (_ ("Select a managed directory that claims the duplicate key."));
            plan.set_string_list ("repair", "dirs", dirs.to_array ());
            var config = current.config;
            foreach (var slot in replacements.values) {
                var replacement = slot.replacement;
                foreach (var mapped in current.mappings.get_values ()) {
                    if (mapped.ascii_down () == replacement.ascii_down ())
                        throw new IOError.EXISTS (_ ("A Steam mapping already refers to the replacement key: %s").printf (replacement));
                }
            }
            foreach (var app in assignments.entries) {
                uint appid;
                var slot = replacements.get (app.value);
                if (!uint.try_parse (app.key, out appid) || app.key != appid.to_string () || slot == null)
                    throw new IOError.INVALID_ARGUMENT (_ ("Invalid repair assignment for AppID %s.").printf (app.key));
                if (appid == 0 && slot.macos_only)
                    throw new IOError.INVALID_ARGUMENT (_ ("A macOS-only tool cannot be the global Steam default."));
                var baseline = current.mappings.get (appid);
                var inherits = appid != 0 && (baseline == null || baseline == "Default")
                    && current.mappings.get (0) == key;
                if (baseline != key && !inherits)
                    throw new IOError.INVALID_ARGUMENT (_ ("AppID %s must currently use the shared key and name a rekeyed directory.").printf (app.key));
                config = configuration.plan_repair_mapping (config, appid, baseline, slot.replacement);
            }
            plan.set_string ("repair", "config-after", config);
            return plan;
        }

        private Gee.Set<string> validate_plan (KeyFile plan, SteamKeyRepairPreview current) throws Error {
            if (plan.get_integer ("repair", "version") != 1)
                throw new IOError.INVALID_DATA (_ ("This Steam repair journal version is unsupported."));
            if (plan.get_string ("repair", "target") != target.id)
                throw new IOError.INVALID_DATA (_ ("The repair journal belongs to another Steam target."));
            var key = plan.get_string ("repair", "key");
            var old_config = plan.get_string ("repair", "config-before");
            var new_config = plan.get_string ("repair", "config-after");

            var affected = new SteamKeyRepairPreview (old_config, current.pending);
            var planned_paths = new Gee.HashMap<string, string> ();
            var planned_keys = new Gee.HashSet<string> ();
            var dirs = plan.get_string_list ("repair", "dirs");
            for (var i = 0; i < dirs.length; i++) {
                var path = slot_path (dirs[i]);
                var section = "slot:" + i.to_string ();
                var manifest = Utils.Filesystem.read_regular_text (manifest_path (path));
                var before = plan.get_string (section, "before");
                var after = plan.get_string (section, "after");
                var replacement = plan.get_string (section, "replacement");
                if ((manifest != before && manifest != after)
                    || Utils.Filesystem.read_regular_text (Path.build_filename (path, Utils.Metadata.FILENAME)) != plan.get_string (section, "metadata"))
                    throw new IOError.BUSY (_ ("The installed tool changed since the repair was planned: %s").printf (path));
                planned_paths.set (path, manifest == before ? key : replacement);
                planned_keys.add (replacement.ascii_down ());
            }
            foreach (var claim in current.claims) {
                if (!planned_keys.contains (claim.key.ascii_down ()))
                    continue;
                if (planned_paths.get (claim.path) != claim.key || claim.replacement == "")
                    throw new IOError.EXISTS (_ ("A Steam key in the repair is claimed by another tool: %s").printf (claim.path));
                planned_paths.unset (claim.path);
            }
            if (!planned_paths.is_empty)
                throw new IOError.BUSY (_ ("A tool in the repair is no longer discoverable."));
            configuration.validate_repair_mappings (current.config, old_config, new_config, planned_keys);
            var after = SteamConfigurationService.read_repair_mappings (new_config);
            foreach (var record in current.pending) {
                var intent = record.receipt.configuration_intent;
                uint appid;
                if (intent != null && intent.operation == SteamConfigurationOperation.COMPATIBILITY_MAPPING
                    && (affected.affects (intent, key)
                        || (uint.try_parse (intent.field_id, out appid)
                            && (after.get (appid) != affected.mappings.get (appid)
                                || (appid != 0 && !intent.desired_present && after.get (0) != affected.mappings.get (0))))
                        || (intent.desired_present && planned_keys.contains (intent.desired.ascii_down ()))))
                    throw new IOError.BUSY (_ ("A pending ProtonPlus compatibility edit conflicts with the repair for AppID %s.").printf (intent.field_id));
            }
            return planned_keys;
        }

        private void finish (KeyFile plan) throws Error {
            validate_plan (plan, preview ());
            var dirs = plan.get_string_list ("repair", "dirs");
            for (var i = 0; i < dirs.length; i++) {
                var path = manifest_path (slot_path (dirs[i]));
                var section = "slot:" + i.to_string ();
                var current = Utils.Filesystem.read_regular_text (path);
                var after = plan.get_string (section, "after");
                if (current == after)
                    continue;
                if (current != plan.get_string (section, "before"))
                    throw new IOError.BUSY (_ ("A compatibility tool manifest changed during the repair."));
                require_stopped ();
                Utils.Filesystem.replace_text_durably (path, after);
            }
            var relevant_keys = validate_plan (plan, preview ());
            configuration.apply_repair_mappings (target, config_path, plan.get_string ("repair", "config-before"),
                plan.get_string ("repair", "config-after"), relevant_keys);
            require_stopped ();
            if (FileUtils.unlink (journal_path) != 0)
                throw new IOError.FAILED (_ ("The completed repair journal could not be removed."));
            foreach (var group in steam.groups) {
                group.invalidate_installed_state ();
                group.refresh_installed_state (false);
            }
            steam.publish_repaired_mappings (
                SteamConfigurationService.read_repair_mappings (Utils.Filesystem.read_regular_text (config_path)), configuration);
        }

        private string slot_path (string dir) throws Error {
            var path = Path.build_filename (root, dir);
            Posix.Stat info = {};
            if (dir == "" || dir == "." || dir == ".." || dir != Path.get_basename (dir)
                || Posix.lstat (path, out info) != 0 || !Posix.S_ISDIR (info.st_mode))
                throw new IOError.INVALID_DATA (_ ("A repair directory is missing or unsafe."));
            return path;
        }

        private static string manifest_path (string directory) {
            return Path.build_filename (directory, "compatibilitytool.vdf");
        }

        private void require_stopped () throws Error {
            var snapshot = sessions.inspect (target);
            if (snapshot.state != SteamSessionState.STOPPED || snapshot.state_confidence != SteamEvidenceLevel.CONFIRMED)
                throw new IOError.BUSY (_ ("Exit Steam completely before applying or resuming this repair."));
        }
    }
}
