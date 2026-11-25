namespace ProtonPlus.Models.Games {
    public class Heroic : Game {
        private Services.HeroicGameRecord record;
        private Services.HeroicLaunchService launch_service;

        public Services.HeroicStore store { get { return record.store; } }
        public string app_name { get { return record.app_name; } }
        public string game_id { owned get { return "%s:%s:%s".printf (launcher.instance_id, store.protocol_id (), app_name); } }
        public override bool has_game_directory { get { return installdir != ""; } }
        public override bool has_prefix_directory { get { return prefixdir != ""; } }
        public override bool can_launch { get { return true; } }
        public override bool can_edit_compatibility_tool { get { return false; } }

        internal Heroic (Services.HeroicGameRecord record, Launchers.HeroicGamesLauncher launcher,
            Services.HeroicLaunchService launch_service) {
            base (record.title, record.game_directory, record.prefix_directory, 0, launcher);
            this.record = record;
            this.launch_service = launch_service;
            is_native = record.native_game;
            compatibility_tool = record.runner_name ?? "Default";
        }

        public override string? get_game_tool_title () {
            if (is_native)
                return _("Native");
            if (!record.settings_available)
                return _("Configuration unavailable");
            var name = record.runner_name;
            if (!record.inherits_runner)
                return name;
            return name != null && name != "" ? _("Inherited (%s)").printf (name) : _("Inherited");
        }

        public override bool change_compatibility_tool (string compatibility_tool) {
            return false;
        }

        public override async Subprocess? launch_external () throws Error {
            var flatpak = launcher.installation_type == Launcher.InstallationTypes.FLATPAK;
            Subprocess? process = null;
            Error? failure = null;
            SourceFunc resume = launch_external.callback;
            new Thread<void> ("heroic-launch", () => {
                try {
                    process = launch_service.launch (flatpak, store, app_name);
                } catch (Error error) {
                    failure = error;
                }
                Idle.add ((owned) resume);
            });
            yield;
            if (failure != null)
                throw (owned) failure;
            return process;
        }
    }
}
