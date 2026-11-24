namespace ProtonPlus.Models.Games {
    public class ProtonAutogen : Game {
        private Utils.ProtonAutogenProfile profile;
        private bool writing_tool;

        public string executable_path { get { return profile.path; } }
        public bool can_launch { get { return ((Launchers.ProtonAutogen) launcher).command_installed; } }

        public ProtonAutogen (Utils.ProtonAutogenProfile profile, Launchers.ProtonAutogen launcher) {
            base (profile.name, Path.get_dirname (profile.path), "", 0, launcher);
            this.profile = profile;
            refresh_tool_selection ();
        }

        internal void refresh_tool_selection () {
            var selected = ((Launchers.ProtonAutogen) launcher).get_profile_tool_id (profile);
            if (compatibility_tool != selected)
                compatibility_tool = selected;
        }

        public override bool change_compatibility_tool (string compat_tool) {
            if (writing_tool)
                return false;
            var autogen = (Launchers.ProtonAutogen) launcher;
            return accept_profile (write_profile (autogen.find_game_tool (compat_tool), profile, compat_tool));
        }

        public override async bool change_compatibility_tool_async (string compat_tool, Cancellable? cancellable = null) {
            if (writing_tool)
                return false;
            writing_tool = true;
            var autogen = (Launchers.ProtonAutogen) launcher;
            var tool = autogen.find_game_tool (compat_tool);
            var expected = profile;
            Utils.ProtonAutogenProfile? updated = null;
            SourceFunc callback = change_compatibility_tool_async.callback;
            new Thread<void> ("proton-autogen-write", () => {
                updated = write_profile (tool, expected, compat_tool, cancellable);
                Idle.add ((owned) callback);
            });
            yield;
            writing_tool = false;
            return accept_profile (updated);
        }

        private static Utils.ProtonAutogenProfile? write_profile (CompatibilityTool? tool,
            Utils.ProtonAutogenProfile expected, string compat_tool, Cancellable? cancellable = null) {
            try {
                cancellable?.set_error_if_cancelled ();
                if (compat_tool != "Default" && !Launchers.ProtonAutogen.game_tool_remains_available (tool))
                    return null;
                return Utils.ProtonAutogenConfig.update_proton (expected, compat_tool == "Default" ? "" : compat_tool, cancellable);
            } catch (Error error) {
                debug ("Could not update Proton-Autogen profile: %s", error.message);
                return null;
            }
        }

        private bool accept_profile (Utils.ProtonAutogenProfile? updated) {
            if (updated == null)
                return false;
            profile = updated;
            refresh_tool_selection ();
            return true;
        }
    }
}
