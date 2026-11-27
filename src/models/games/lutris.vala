namespace ProtonPlus.Models.Games {
    public class Lutris : Game {
        private Services.LutrisGameRecord record;
        private Services.LutrisConfigurationService configuration;
        private bool saving;
        private string? edit_error;
        private bool probe_failed;
        public string? pending_conversion { get; private set; }
        private string? override_version;
        private Gee.List<CompatibilityTool>? choices;
        private bool probed_custom;
        private uint runner_request;

        public int64 id { get { return record.id; } }
        public override bool has_game_directory { get { return installdir != ""; } }
        public override bool has_prefix_directory { get { return prefixdir != ""; } }
        public override bool can_launch { get { return true; } }
        public override bool can_edit_compatibility_tool { get { return Services.LutrisConfigurationService.can_edit (record); } }
        public override string? compatibility_edit_error { get { return edit_error; } }

        internal Lutris (Services.LutrisGameRecord record, Launchers.Lutris launcher,
            Services.LutrisConfigurationService configuration,
            Gee.List<CompatibilityTool>? choices, bool probe_failed) {
            base (record.name, record.game_directory, record.accessible_prefix, 0, launcher);
            this.record = record;
            this.configuration = configuration;
            this.probe_failed = probe_failed;
            this.choices = choices;
            is_native = record.runner == "linux";
            override_version = record.config?.get_setting ("wine", "version");
            compatibility_tool = override_version ?? "Default";
        }

        public override string? get_game_tool_title () {
            if (record.runner != "wine")
                return is_native ? _("Native") : record.runner;
            if (record.config == null)
                return _("Configuration unavailable");
            if (override_version != null) {
                var effective = Services.LutrisConfigurationService.effective_runner (record, override_version, choices);
                return effective == override_version ? describe_runner (effective)
                    : _("%s (uses %s)").printf (describe_runner (override_version), describe_runner (effective));
            }
            return _("Inherited (%s)").printf (describe_runner (inherited_runner ()));
        }

        private string inherited_runner () {
            return Services.LutrisConfigurationService.effective_runner (record, null, choices);
        }

        private string describe_runner (string version) {
            var tool = Services.LutrisConfigurationService.find_runner (choices, version);
            var title = tool?.display_title ??
                (version == Services.LutrisConfigurationService.LATEST ? _("GE-Proton (Latest)") : version);
            if (version == "custom") {
                var path = record.custom_path;
                title = path != null && path != "" ? _("Custom (%s)").printf (path) : _("Custom");
                if (!probed_custom && !probe_failed)
                    return title;
            }
            string? diagnostic = null;
            if (probe_failed)
                diagnostic = _("Runner probe failed");
            else if (choices != null)
                diagnostic = Services.LutrisConfigurationService.runner_diagnostic (record, tool);
            return diagnostic == null ? title : _("%s (%s)").printf (title, diagnostic);
        }

        public override async Gee.List<CompatibilityTool>? load_game_tool_choices () {
            edit_error = null;
            if (!can_edit_compatibility_tool)
                return null;
            var expected = record;
            var request = ++runner_request;
            Gee.List<CompatibilityTool>? loaded = null;
            Services.LutrisGameRecord? current = null;
            string? failure = null;
            SourceFunc resume = load_game_tool_choices.callback;
            new Thread<void> ("lutris-runners", () => {
                try {
                    current = configuration.revalidate (expected, false);
                    loaded = configuration.runners_for (current);
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            if (request != runner_request || record != expected)
                return null;
            if (failure != null) {
                probe_failed = current != null;
                edit_error = probe_failed ? _("Runner probe failed: %s").printf (failure) : failure;
                return null;
            }
            if (current == null)
                return null;
            record = current;
            choices = loaded;
            probed_custom = loaded != null;
            probe_failed = false;
            override_version = record.config?.get_setting ("wine", "version");
            compatibility_tool = override_version ?? "Default";
            var result = new Gee.ArrayList<CompatibilityTool> ();
            var inherited = inherited_runner ();
            var inherit_tool = Services.LutrisConfigurationService.find_runner (choices, inherited);
            result.add (new CompatibilityTool (
                _("Inherit Lutris default (%s)").printf (describe_runner (inherited)), "Default") {
                availability_diagnostic = Services.LutrisConfigurationService.runner_diagnostic (record, inherit_tool)
            });
            if (loaded != null) {
                foreach (var tool in loaded) {
                    if (!tool.is_assignable)
                        continue;
                    var diagnostic = Services.LutrisConfigurationService.runner_diagnostic (record, tool);
                    if (diagnostic == null) {
                        result.add (tool);
                    } else if (tool.internal_title == Services.LutrisConfigurationService.LATEST ||
                        tool.internal_title == override_version) {
                        result.add (new CompatibilityTool (describe_runner (tool.internal_title), tool.internal_title) {
                            is_assignable = false, is_available = false, availability_diagnostic = diagnostic
                        });
                    }
                }
            }
            if (override_version != null && !result.any_match ((tool) => tool.internal_title == override_version)) {
                result.add (new CompatibilityTool (describe_runner (override_version), override_version) {
                    is_assignable = false
                });
            }
            return result;
        }

        public override bool change_compatibility_tool (string compat_tool) {
            return false;
        }

        public override async bool change_compatibility_tool_async (string compat_tool, Cancellable? cancellable = null) {
            return yield save_runner (compat_tool, cancellable, null);
        }

        public async bool confirm_runner_change (string compat_tool, string confirmation, Cancellable? cancellable) {
            return yield save_runner (compat_tool, cancellable, confirmation);
        }

        private async bool save_runner (string compat_tool, Cancellable? cancellable, string? confirmation) {
            if (saving)
                return false;
            pending_conversion = null;
            saving = true;
            edit_error = null;
            var expected = record;
            var version = compat_tool == "Default" ? null : compat_tool;
            Services.LutrisGameRecord? updated = null;
            string? failure = null;
            bool saved = false;
            string? required_confirmation = null;
            SourceFunc resume = save_runner.callback;
            new Thread<void> ("lutris-write", () => {
                try {
                    configuration.save_version (expected, version, cancellable, confirmation);
                    saved = true;
                    var records = configuration.read_library (expected.id);
                    if (records.size == 1 && expected.matches (records[0]) &&
                        records[0].config?.get_setting ("wine", "version") == version)
                        updated = records[0];
                } catch (Services.LutrisRunnerChangeError.CONFIRM_CONVERSION error) {
                    required_confirmation = error.message;
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            saving = false;
            pending_conversion = required_confirmation;
            if (saved) {
                if (updated != null)
                    record = updated;
                override_version = version;
                compatibility_tool = compat_tool;
            } else {
                edit_error = failure;
            }
            return saved;
        }

        public override async Subprocess? launch_external () throws Error {
            Subprocess? process = null;
            Error? failure = null;
            var expected = record;
            SourceFunc resume = launch_external.callback;
            new Thread<void> ("lutris-launch", () => {
                try {
                    process = configuration.launch (expected);
                } catch (Error error) {
                    failure = error;
                }
                Idle.add ((owned) resume);
            });
            yield;
            if (failure != null)
                throw (!) failure;
            return process;
        }
    }
}
