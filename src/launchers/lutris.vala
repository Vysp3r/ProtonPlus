namespace ProtonPlus.Shared.Launchers {
    public class Lutris {
        static Models.Group[] get_groups (Models.Launcher launcher) {
            var groups = new Models.Group[3];

            groups[0] = new Models.Group ("Wine", "/runners/wine", launcher);
            groups[0].description = _("Program which allows running Microsoft Windows programs");
            groups[0].runners = get_wine_runners (groups[0]);

            groups[1] = new Models.Group ("DXVK", "/runtime/dxvk", launcher);
            groups[1].description = _("Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine");
            groups[1].runners = get_dxvk_runners (groups[1]);

            groups[2] = new Models.Group ("VKD3D", "/runtime/vkd3d", launcher);
            groups[2].description = _("Fork of Wine's VKD3D which aims to implement the full Direct3D 12 API on top of Vulkan");
            groups[2].runners = get_vkd3d_runners (groups[2]);

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

            var wine_ge = new Models.Runner (group, "Wine-GE", _("Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris."), "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, Models.Runner.title_types.LUTRIS_WINE_GE);
            wine_ge.old_asset_location = 83;
            wine_ge.old_asset_position = 0;

            var wine_lutris = new Models.Runner (group, "Wine-Lutris", _("Improved by Lutris to offer better compatibility or performance in certain games."), "https://api.github.com/repos/lutris/wine/releases", 0, Models.Runner.title_types.LUTRIS_WINE);
            wine_lutris.request_asset_exclude = { "ge-lol" };

            var kron4ek_vanilla = new Models.Runner (group, "Wine-Vanilla (Kron4ek)", _("Wine build compiled from the official WineHQ sources."), "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 1, Models.Runner.title_types.KRON4EK_VANILLA);
            kron4ek_vanilla.request_asset_exclude = { "proton", ".0." };

            var kron4ek_staging = new Models.Runner (group, "Wine-Staging (Kron4ek)", _("Wine build with the Staging patchset applied."), "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 2, Models.Runner.title_types.KRON4EK_STAGING);
            kron4ek_staging.request_asset_exclude = { "proton", ".0." };

            var kron4ek_staging_tkg = new Models.Runner (group, "Wine-Staging-Tkg (Kron4ek)", _("Wine build with the Staging patchset applied and with many additional useful patches."), "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 3, Models.Runner.title_types.KRON4EK_STAGING_TKG);
            kron4ek_staging_tkg.request_asset_exclude = { "proton", ".0." };

            runners.append (wine_ge);
            runners.append (wine_lutris);
            runners.append (kron4ek_vanilla);
            runners.append (kron4ek_staging);
            runners.append (kron4ek_staging_tkg);

            return runners;
        }

        public static GLib.List<Models.Runner> get_dxvk_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            var dxvk_gplasync = new Models.Runner (group, "DXVK GPL+Async (Ph42oN)", "", "https://gitlab.com/api/v4/projects/Ph42oN%2Fdxvk-gplasync/releases", 0, ProtonPlus.Shared.Models.Runner.title_types.LUTRIS_DXVK_GPLASYNC);
            dxvk_gplasync.endpoint_type = ProtonPlus.Shared.Models.Runner.endpoint_types.GITLAB;

            runners.append (new Models.Runner (group, "DXVK (doitsujin)", "", "https://api.github.com/repos/doitsujin/dxvk/releases", 0, Models.Runner.title_types.DXVK));
            runners.append (new Models.Runner (group, "DXVK Async (Sporif)", "", "https://api.github.com/repos/Sporif/dxvk-async/releases", 0, Models.Runner.title_types.DXVK_ASYNC_SPORIF));
            runners.append (new Models.Runner (group, "DXVK Async (gnusenpai)", _("Contains RTX fix for Star Citizen."), "https://api.github.com/repos/gnusenpai/dxvk/releases", 0, Models.Runner.title_types.LUTRIS_DXVK_ASYNC_GNUSENPAI));
            runners.append (dxvk_gplasync);

            return runners;
        }

        public static GLib.List<Models.Runner> get_vkd3d_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            runners.append (new Models.Runner (group, "VKD3D-Lutris", "", "https://api.github.com/repos/lutris/vkd3d/releases", 0, Models.Runner.title_types.LUTRIS_VKD3D));
            runners.append (new Models.Runner (group, "VKD3D-Proton", "", "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases", 0, Models.Runner.title_types.LUTRIS_VKD3D_PROTON));

            return runners;
        }
    }
}