namespace ProtonPlus.Models.Launchers {
    public class Lutris : Launcher {
        public const string FAMILY_ID = "lutris";

        private Services.LutrisConfigurationService configuration;
        public string? library_error { get; private set; }
        public override string? game_library_error { get { return library_error; } }
        public override bool load_library_on_startup { get { return false; } }
        public override bool supports_bulk_game_edit { get { return false; } }

        public Lutris (Launcher.InstallationTypes installation_type,
            Services.LutrisConfigurationService? configuration = null) {
            string[] directories = null;

            switch (installation_type) {
                case Launcher.InstallationTypes.SYSTEM:
                    directories = new string[] {
                        Path.build_filename (Services.LutrisConfigurationService.native_data_home (), "lutris"),
                        Path.build_filename (Environment.get_home_dir (), ".local", "share", "lutris")
                    };
                    break;
                case Launcher.InstallationTypes.FLATPAK:
                    directories = new string[] { "%s/.var/app/net.lutris.Lutris/data/lutris".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.SNAP:
                    break;
            }

            base ("Lutris", installation_type, "%s/lutris.svg".printf (Config.RESOURCE_BASE), directories, FAMILY_ID);
            this.configuration = configuration ??
                Services.LutrisConfigurationService.for_installation (installation_type == InstallationTypes.FLATPAK);
            has_library_support = installation_type != InstallationTypes.SNAP;
        }

        public override async bool load_game_library () {
            Gee.List<Services.LutrisGameRecord>? records = null;
            Gee.List<CompatibilityTool>? choices = null;
            string? inherited = null;
            string? failure = null;
            SourceFunc resume = load_game_library.callback;
            new Thread<void> ("lutris-library", () => {
                try {
                    records = configuration.read_library ();
                    if (records.any_match ((record) => record.runner == "wine" && record.config != null)) {
                        inherited = configuration.inherited_runner ();
                        try {
                            choices = configuration.installed_runners ();
                        } catch (Error error) {
                            debug ("Could not read Lutris runners: %s", error.message);
                        }
                    }
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
                discovered.append (new Games.Lutris (record, this, configuration, inherited, choices));
            games = (owned) discovered;
            return true;
        }
    }
}
