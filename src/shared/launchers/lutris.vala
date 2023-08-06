namespace ProtonPlus.Shared.Launchers {
    public class Lutris {
        static Models.Group[] get_groups (Models.Launcher launcher) {
            var groups = new Models.Group[2];

            groups[0] = new Models.Group ("Wine", "/runners/wine", launcher);
            groups[0].runners = get_wine_runners (groups[0]);

            groups[1] = new Models.Group ("DXVK", "/runtime/dxvk", launcher);
            groups[1].runners = get_dxvk_runners (groups[1]);

            return groups;
        }

        public static Models.Launcher get_launcher () {
            var directories = new string[] { "/.local/share/lutris" };

            var launcher = new Models.Launcher (
                                                "Lutris",
                                                "System",
                                                "/com/vysp3r/ProtonPlus/lutris.png",
                                                directories
            );

            if (launcher.installed) launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static Models.Launcher get_flatpak_launcher () {
            var directories = new string[] { "/.var/app/net.lutris.Lutris/data/lutris" };

            var launcher = new Models.Launcher (
                                                "Lutris",
                                                "Flatpak",
                                                "/com/vysp3r/ProtonPlus/lutris.png",
                                                directories
            );

            if (launcher.installed) launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static GLib.List<Models.Runner> get_wine_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            var wine_ge = new Models.Runner (group, "Wine-GE", _("Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose."), "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, Models.Runner.title_types.LUTRIS_WINE_GE);
            wine_ge.old_asset_location = 83;
            wine_ge.old_asset_position = 0;

            var wine_lutris = new Models.Runner (group, "Wine-Lutris", _("Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games."), "https://api.github.com/repos/lutris/wine/releases", 0, Models.Runner.title_types.LUTRIS_WINE);

            var kron4ek_vanilla = new Models.Runner (group, "Kron4ek Wine-Builds Vanilla", _("Compatibility tool \"Wine\" to run Windows games on Linux. Official version from the WineHQ sources, compiled by Kron4ek."), "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 1, Models.Runner.title_types.LUTRIS_KRON4EK_VANILLA);
            kron4ek_vanilla.request_asset_exclude = "proton";

            var kron4ek_tkg = new Models.Runner (group, "Kron4ek Wine-Builds Tkg", _("Compatibility tool \"Wine\" to run Windows games on Linux. Official version from the WineHQ sources, compiled by Kron4ek."), "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 2, Models.Runner.title_types.LUTRIS_KRON4EK_TKG);
            kron4ek_tkg.request_asset_exclude = "proton";

            runners.append (wine_ge);
            runners.append (wine_lutris);
            runners.append (kron4ek_vanilla);
            runners.append (kron4ek_tkg);

            return runners;
        }

        public static GLib.List<Models.Runner> get_dxvk_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            var dxvk_gplasync = new Models.Runner (group, "DXVK GPL+Async (Ph42oN)", "", "https://gitlab.com/api/v4/projects/Ph42oN%2Fdxvk-gplasync/releases", 0, ProtonPlus.Shared.Models.Runner.title_types.LUTRIS_DXVK_GPLASYNC);
            dxvk_gplasync.endpoint_type = ProtonPlus.Shared.Models.Runner.endpoint_types.GITLAB;

            runners.append (new Models.Runner (group, "DXVK (doitsujin)", _(""), "https://api.github.com/repos/doitsujin/dxvk/releases", 0, Models.Runner.title_types.LUTRIS_DXVK));
            runners.append (new Models.Runner (group, "DXVK Async (Sporif)", _(""), "https://api.github.com/repos/Sporif/dxvk-async/releases", 0, Models.Runner.title_types.LUTRIS_DXVK_ASYNC_SPORIF));
            runners.append (new Models.Runner (group, "DXVK Async (gnusenpai)", _("RTX fix for Star Citizen."), "https://api.github.com/repos/gnusenpai/dxvk/releases", 0, Models.Runner.title_types.LUTRIS_DXVK_ASYNC_GNUSENPAI));
            runners.append (dxvk_gplasync);

            return runners;
        }
    }
}