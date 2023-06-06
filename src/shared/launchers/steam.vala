namespace ProtonPlus.Shared.Launchers {
    public class Steam {
        static Models.Group[] get_groups (Models.Launcher launcher) {
            var groups = new Models.Group[1];

            groups[0] = new Models.Group ("Runners", "/compatibilitytools.d", launcher);
            groups[0].runners = get_runners (groups[0]);

            return groups;
        }

        public static Models.Launcher get_launcher () {
            var directories = new string[] { "/.local/share/Steam",
                                             "/.steam/root",
                                             "/.steam/steam",
                                             "/.steam/debian-installation" };

            var launcher = new Models.Launcher (
                                                "Steam",
                                                "System",
                                                "/com/vysp3r/ProtonPlus/steam.png",
                                                directories
            );

            if (launcher.installed) launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static Models.Launcher get_flatpak_launcher () {
            var directories = new string[] { "/.var/app/com.valvesoftware.Steam/data/Steam" };

            var launcher = new Models.Launcher (
                                                "Steam",
                                                "Flatpak",
                                                "/com/vysp3r/ProtonPlus/steam.png",
                                                directories
            );

            if (launcher.installed) launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static Models.Launcher get_snap_launcher () {
            var directories = new string[] { "/snap/steam/common/.steam/root" };

            var launcher = new Models.Launcher (
                                                "Steam",
                                                "Snap",
                                                "/com/vysp3r/ProtonPlus/steam.png",
                                                directories
            );

            if (launcher.installed) launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static GLib.List<Models.Runner> get_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            runners.append (new Models.Runner (group, "Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1, Models.Runner.title_types.NONE));
            runners.append (new Models.Runner (group, "Luxtorpeda", "Luxtorpeda provides Linux-native game engines for specific Windows-only games.", "https://api.github.com/repos/luxtorpeda-dev/luxtorpeda/releases", 0, Models.Runner.title_types.TOOL_NAME));
            runners.append (new Models.Runner (group, "Boxtron", "Steam Play compatibility tool to run DOS games using native Linux DOSBox.", "https://api.github.com/repos/dreamer/boxtron/releases", 0, Models.Runner.title_types.TOOL_NAME));
            runners.append (new Models.Runner (group, "Roberta", "Steam Play compatibility tool to run adventure games using native Linux ScummVM.", "https://api.github.com/repos/dreamer/roberta/releases", 0, Models.Runner.title_types.TOOL_NAME));
            runners.append (new Models.Runner (group, "NorthstarProton", "Custom Proton build for running the Northstar client for Titanfall 2.", "https://api.github.com/repos/cyrv6737/NorthstarProton/releases", 0, Models.Runner.title_types.TOOL_NAME));

            // var runner = new Models.Runner (group, "Proton Tkg", "Custom Proton build for running Windows games, built with the Wine-tkg build system.", "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/29873769/runs", 0, Models.Runner.title_types.PROTON_TKG);
            // runner.is_using_github_actions = true;
            // runners.append (runner);

            return runners;
        }
    }
}