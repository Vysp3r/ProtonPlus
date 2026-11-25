namespace ProtonPlus.Models.Launchers {
    public class HeroicGamesLauncher : Launcher {
        public const string FAMILY_ID = "heroic";
        public const string FLATPAK_ID = Services.HeroicLaunchService.FLATPAK_ID;

        private Services.HeroicLibrary library;
        private Services.HeroicLaunchService launch_service;
        private string? library_error;
        public override string? game_library_error { get { return library_error; } }
        public override bool load_library_on_startup { get { return false; } }
        public override bool supports_bulk_game_edit { get { return false; } }

        public HeroicGamesLauncher (Launcher.InstallationTypes installation_type,
            string? home_override = null, string? config_home_override = null,
            Services.HeroicLaunchService? launch_service = null) {
            var home = home_override ?? Environment.get_home_dir ();
            var config_home = config_home_override ?? (Globals.IS_FLATPAK
                ? Environment.get_variable ("HOST_XDG_CONFIG_HOME") : Environment.get_user_config_dir ());
            var default_config_home = Path.build_filename (home, ".config");
            if (config_home == null || !Path.is_absolute (config_home))
                config_home = default_config_home;

            string[] directories = {};
            string root = "";
            switch (installation_type) {
            case Launcher.InstallationTypes.SYSTEM:
                root = Path.build_filename (config_home, "heroic");
                directories = { root, Path.build_filename (default_config_home, "heroic") };
                break;
            case Launcher.InstallationTypes.FLATPAK:
                root = Path.build_filename (home, ".var", "app", FLATPAK_ID, "config", "heroic");
                directories = { root };
                break;
            default:
                break;
            }

            base ("Heroic Games Launcher", installation_type, "%s/hgl.svg".printf (Config.RESOURCE_BASE), directories, FAMILY_ID);
            this.library = new Services.HeroicLibrary (root, home);
            this.launch_service = launch_service ?? Services.HeroicLaunchService.for_package (Globals.IS_FLATPAK, home);
            has_library_support = installation_type != InstallationTypes.SNAP;
        }

        public override async bool load_game_library () {
            if (!has_library_support)
                return false;

            Gee.List<Services.HeroicGameRecord>? records = null;
            string? failure = null;
            SourceFunc resume = load_game_library.callback;
            new Thread<void> ("heroic-library", () => {
                try {
                    records = library.read ();
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            library_error = failure;
            if (records == null)
                return false;

            var discovered = new List<Game> ();
            foreach (var record in records)
                discovered.prepend (new Games.Heroic (record, this, launch_service));
            discovered.reverse ();
            games = (owned) discovered;
            return true;
        }
    }
}
