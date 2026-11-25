namespace ProtonPlus.Models.Games {
    public class Lutris : Game {
        private Services.LutrisGameRecord record;
        private Services.LutrisConfigurationService configuration;
        private bool saving;
        private string? edit_error;
        private string? inherited;
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
            Services.LutrisConfigurationService configuration, string? inherited,
            Gee.List<CompatibilityTool>? choices) {
            base (record.name, record.game_directory, record.accessible_prefix, 0, launcher);
            this.record = record;
            this.configuration = configuration;
            this.inherited = inherited;
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
            if (override_version != null)
                return describe_runner (override_version);
            return inherited != null ? _("Inherited (%s)").printf (describe_runner (inherited))
                : _("Inherited");
        }

        private string describe_runner (string version) {
            if (version == "custom") {
                var path = record.custom_path;
                var title = path != null && path != "" ? _("Custom (%s)").printf (path) : _("Custom");
                if (probed_custom && choices != null && !choices.any_match ((tool) => tool.internal_title == "custom"))
                    return _("%s (Unavailable)").printf (title);
                return title;
            }
            if (choices != null) {
                var tool = choices.first_match ((candidate) => candidate.internal_title == version);
                return tool != null ? tool.display_title : _("%s (Unavailable)").printf (version);
            }
            return version;
        }

        public override async Gee.List<CompatibilityTool>? load_game_tool_choices () {
            edit_error = null;
            if (!can_edit_compatibility_tool)
                return null;
            var expected = record;
            var request = ++runner_request;
            Gee.List<CompatibilityTool>? loaded = null;
            Services.LutrisGameRecord? current = null;
            string? inherited_version = null;
            string? failure = null;
            SourceFunc resume = load_game_tool_choices.callback;
            new Thread<void> ("lutris-runners", () => {
                try {
                    current = configuration.revalidate (expected, false);
                    inherited_version = configuration.inherited_runner ();
                    try {
                        loaded = configuration.runners_for (current);
                    } catch (Error error) {
                        debug ("Could not refresh Lutris runners: %s", error.message);
                    }
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            if (request != runner_request || record != expected)
                return null;
            if (failure != null) {
                edit_error = failure;
                return null;
            }
            if (current == null)
                return null;
            record = current;
            choices = loaded;
            probed_custom = loaded != null;
            inherited = inherited_version;
            override_version = record.config?.get_setting ("wine", "version");
            compatibility_tool = override_version ?? "Default";
            var result = new Gee.ArrayList<CompatibilityTool> ();
            result.add (new CompatibilityTool (inherited != null
                ? _("Inherit Lutris default (%s)").printf (describe_runner (inherited))
                : _("Inherit Lutris default"), "Default"));
            if (loaded != null) {
                foreach (var tool in loaded) {
                    if (tool.is_assignable)
                        result.add (tool);
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
            if (saving)
                return false;
            saving = true;
            edit_error = null;
            var expected = record;
            var version = compat_tool == "Default" ? null : compat_tool;
            Services.LutrisGameRecord? updated = null;
            string? failure = null;
            string? inherited_version = null;
            bool saved = false;
            SourceFunc resume = change_compatibility_tool_async.callback;
            new Thread<void> ("lutris-write", () => {
                try {
                    configuration.save_version (expected, version, cancellable);
                    saved = true;
                    inherited_version = configuration.inherited_runner ();
                    var records = configuration.read_library (expected.id);
                    if (records.size == 1 && expected.matches (records[0]) &&
                        records[0].config?.get_setting ("wine", "version") == version)
                        updated = records[0];
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            saving = false;
            if (saved) {
                if (updated != null)
                    record = updated;
                inherited = inherited_version;
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
