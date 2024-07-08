namespace ProtonPlus.Launchers {
    public class Bottles {
        static Models.Group[] get_groups (Models.Launcher launcher) {
            var groups = new Models.Group[2];

            groups[0] = new Models.Group (_("Runners"), "/runners", launcher);
            groups[0].description = _("Compatibility tool to run Windows games on Linux");
            groups[0].runners = get_runners (groups[0]);

            groups[1] = new Models.Group ("DXVK", "/dxvk", launcher);
            groups[1].description = _("Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine");
            groups[1].runners = get_dxvk_runners (groups[1]);

            return groups;
        }

        public static Models.Launcher get_launcher () {
            var directories = new string[] { "/.local/share/bottles" };

            var launcher = new Models.Launcher (
                                                "Bottles",
                                                "System",
                                                Constants.RESOURCE_BASE + "/bottles.png",
                                                directories
            );

            if (launcher.installed)launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static Models.Launcher get_flatpak_launcher () {
            var directories = new string[] { "/.var/app/com.usebottles.bottles/data/bottles" };

            var launcher = new Models.Launcher (
                                                "Bottles",
                                                "Flatpak",
                                                Constants.RESOURCE_BASE + "/bottles.png",
                                                directories
            );

            if (launcher.installed)launcher.groups = get_groups (launcher);

            return launcher;
        }

        public static GLib.List<Models.Runner> get_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            var proton_ge = new Models.Runner (group, "Proton-GE", _("Contains improvements over Valve's default Proton."), "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1, Models.Runner.title_types.BOTTLES_PROTON_GE);
            proton_ge.old_asset_location = 95;
            proton_ge.old_asset_position = 0;

            var wine_ge = new Models.Runner (group, "Wine-GE", _("Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris."), "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, Models.Runner.title_types.BOTTLES_WINE_GE);
            wine_ge.old_asset_location = 83;
            wine_ge.old_asset_position = 0;

            var wine_lutris = new Models.Runner (group, "Wine-Lutris", _("Improved by Lutris to offer better compatibility or performance in certain games."), "https://api.github.com/repos/lutris/wine/releases", 0, Models.Runner.title_types.BOTTLES_WINE_LUTRIS);
            wine_lutris.request_asset_exclude = { "GE-Proton", "ge-lol" };

            var other = new Models.Runner (group, "Other", "", "https://api.github.com/repos/bottlesdevs/wine/releases", 0, Models.Runner.title_types.BOTTLES);
            other.use_name_instead_of_tag_name = true;

            runners.append (proton_ge);
            runners.append (wine_ge);
            runners.append (wine_lutris);
            runners.append (other);

            return runners;
        }

        public static GLib.List<Models.Runner> get_dxvk_runners (Models.Group group) {
            var runners = new GLib.List<Models.Runner> ();

            runners.append (new Models.Runner (group, "DXVK", "", "https://api.github.com/repos/doitsujin/dxvk/releases", 0, Models.Runner.title_types.DXVK));
            runners.append (new Models.Runner (group, "DXVK Async", "", "https://api.github.com/repos/Sporif/dxvk-async/releases", 0, Models.Runner.title_types.DXVK_ASYNC_SPORIF));

            return runners;
        }
    }
}
