namespace ProtonPlus.Models.Launchers {
    public class Bottles : Launcher {
        public const string FAMILY_ID = "bottles";

        private Services.BottlesLibrary library;
        private string? library_error;
        private string? library_warning;
        public override string? game_library_error { get { return library_error; } }
        public override string? game_library_warning { get { return library_warning; } }
        public override bool load_library_on_startup { get { return false; } }
        public override bool supports_bulk_game_edit { get { return false; } }

        public Bottles (Launcher.InstallationTypes installation_type, Services.BottlesLibrary? library = null) {
            string[] directories = {};

            switch (installation_type) {
                case Launcher.InstallationTypes.SYSTEM:
                    directories = new string[] {
                        Path.build_filename (Environment.get_user_data_dir (), "bottles"),
                        Path.build_filename (Environment.get_home_dir (), ".local", "share", "bottles")
                    };
                    break;
                case Launcher.InstallationTypes.FLATPAK:
                    directories = new string[] { "%s/.var/app/com.usebottles.bottles/data/bottles".printf (Environment.get_home_dir ()) };
                    break;
                case Launcher.InstallationTypes.SNAP:
                    break;
            }

            base ("Bottles", installation_type, "%s/bottles.svg".printf (Config.RESOURCE_BASE), directories, FAMILY_ID);
            this.library = library ?? new Services.BottlesLibrary (
                installation_type == InstallationTypes.FLATPAK, Globals.IS_FLATPAK);
            has_library_support = installation_type != InstallationTypes.SNAP;
        }

        public override async bool load_game_library () {
            Services.BottlesLibraryResult? result = null;
            string? failure = null;
            SourceFunc resume = load_game_library.callback;
            new Thread<void> ("bottles-library", () => {
                try {
                    result = library.read ();
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            library_error = failure;
            library_warning = result != null && result.partial ? _("Some Bottles programs couldn’t be loaded.") : null;
            var discovered = new List<Game> ();
            if (result != null) {
                foreach (var program in result.programs)
                    discovered.append (new Games.Bottles (program, this, library));
            }
            games = (owned) discovered;
            return result != null;
        }
    }
}
