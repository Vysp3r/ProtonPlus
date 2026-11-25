namespace ProtonPlus.Models.Games {
    public class Bottles : Game {
        private Services.BottlesProgram program;
        private Services.BottlesLibrary library;

        public GLib.Variant identity { get; private set; }
        public override string? library_context { get { return program.bottle; } }
        public override bool has_game_directory { get { return installdir != ""; } }
        public override bool has_prefix_directory { get { return prefixdir != ""; } }
        public override bool can_launch { get { return program.launch_flag != null; } }
        public override bool can_edit_compatibility_tool { get { return false; } }

        internal Bottles (Services.BottlesProgram program, Launchers.Bottles launcher,
            Services.BottlesLibrary library) {
            base (program.name, program.directory, program.prefix, 0, launcher);
            this.program = program;
            this.library = library;
            identity = program.identity (launcher.instance_id);
        }

        public override string? get_game_tool_title () {
            return program.runner ?? "";
        }

        public override bool change_compatibility_tool (string compat_tool) {
            return false;
        }

        public override async Subprocess? launch_external () throws Error {
            if (!can_launch)
                throw new IOError.NOT_SUPPORTED (_("This Bottles program cannot be uniquely targeted."));
            Subprocess? process = null;
            Error? failure = null;
            SourceFunc resume = launch_external.callback;
            new Thread<void> ("bottles-launch", () => {
                try {
                    process = library.launch (program);
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
