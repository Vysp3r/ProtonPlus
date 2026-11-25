namespace ProtonPlus.Models.Games {
    public class Faugus : Game {
        private Services.FaugusGameRecord record;
        private Services.FaugusConfigurationService configuration;
        private Gee.List<CompatibilityTool>? choices;
        private string inherited;
        private string? edit_error;
        private bool saving;
        private uint runner_request;

        public string game_id { get { return record.id; } }
        public string identity { owned get { return "%s/%s".printf (launcher.instance_id, record.id); } }
        public override bool has_game_directory { get { return installdir != ""; } }
        public override bool has_prefix_directory { get { return prefixdir != ""; } }
        public override bool can_launch { get { return record.launchable; } }
        public override bool can_edit_compatibility_tool { get { return record.can_edit (); } }
        public override string? compatibility_edit_error { get { return edit_error; } }

        internal Faugus (Services.FaugusGameRecord record, Launchers.FaugusLauncher launcher,
            Services.FaugusConfigurationService configuration, string inherited, Gee.List<CompatibilityTool>? choices) {
            base (record.title, record.game_directory, record.prefix_directory, 0, launcher);
            this.record = record;
            this.configuration = configuration;
            this.inherited = inherited;
            this.choices = choices;
            is_native = record.runner == "Linux-Native";
            compatibility_tool = record.runner;
        }

        private string describe_runner (string runner) {
            if (runner == "")
                return _("Automatic (UMU)");
            if (runner == "Linux-Native")
                return _("Linux Native");
            if (runner == "Steam")
                return "Steam";
            if (choices == null)
                return runner;
            var tool = choices.first_match (candidate => candidate.internal_title == runner);
            return tool?.display_title ?? _("%s (Unavailable)").printf (runner);
        }

        public override string? get_game_tool_title () {
            if (record.runner != "Default")
                return describe_runner (record.runner);
            return record.settings_available ? _("Inherited (%s)").printf (describe_runner (inherited))
                : _("Inherited");
        }

        public override async Gee.List<CompatibilityTool>? load_game_tool_choices () {
            edit_error = null;
            if (!can_edit_compatibility_tool)
                return null;
            var expected = record;
            var request = ++runner_request;
            Gee.List<CompatibilityTool>? loaded = null;
            Services.FaugusGameRecord? current = null;
            string default_runner = "";
            string? failure = null;
            SourceFunc resume = load_game_tool_choices.callback;
            new Thread<void> ("faugus-runners", () => {
                try {
                    loaded = configuration.editor_choices (expected, out current, out default_runner);
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            if (request != runner_request || record != expected)
                return null;
            edit_error = failure;
            if (loaded == null || current == null)
                return null;
            record = current;
            choices = loaded;
            inherited = default_runner;
            compatibility_tool = current.runner;
            var result = new Gee.ArrayList<CompatibilityTool> ();
            result.add (new CompatibilityTool (_("Inherit Faugus default (%s)").printf (describe_runner (inherited)),
                "Default"));
            foreach (var tool in loaded) {
                if (tool.is_assignable)
                    result.add (tool);
            }
            if (!result.any_match (tool => tool.internal_title == record.runner)) {
                result.add (new CompatibilityTool (describe_runner (record.runner), record.runner) {
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
            Services.FaugusGameRecord? updated = null;
            Gee.List<CompatibilityTool>? loaded = null;
            string default_runner = "";
            string? failure = null;
            SourceFunc resume = change_compatibility_tool_async.callback;
            new Thread<void> ("faugus-write", () => {
                try {
                    updated = configuration.save_runner (expected, compat_tool, cancellable, out default_runner, out loaded);
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            saving = false;
            if (updated == null) {
                edit_error = failure;
                return false;
            }
            record = updated;
            choices = loaded;
            inherited = default_runner;
            compatibility_tool = updated.runner;
            return true;
        }

        public override async Subprocess? launch_external () throws Error {
            Subprocess? process = null;
            Error? failure = null;
            var expected = record;
            SourceFunc resume = launch_external.callback;
            new Thread<void> ("faugus-launch", () => {
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
