namespace ProtonPlus.Models {
    public class Location : Object {
        public string Label { public get; private set; }
        public string InstallDirectory { public get; private set; }
        public ProtonPlus.Models.CompatibilityTool[] Tools { public get; private set; }
        public ProtonPlus.Models.Launcher Launcher { public get; private set; }

        public Location (string label, string install_directory, ProtonPlus.Models.CompatibilityTool[] tools, ProtonPlus.Models.Launcher launcher) {
            this.Label = label;
            this.InstallDirectory = install_directory;
            this.Tools = tools;
            this.Launcher = launcher;
        }

        public static GLib.ListStore GetStore () {
            var store = new GLib.ListStore (typeof (ProtonPlus.Models.Location));

            foreach (var location in GetInstallLocations ()) {
                var dir = Posix.opendir (location.InstallDirectory);

                if (dir != null) {
                    store.append (location);
                }
            }

            return store;
        }

        public static GLib.List<Location> GetInstallLocations () {
            GLib.List<Location> locations = new GLib.List<Location> ();

            string home_dir = GLib.Environment.get_home_dir ();

            string[] steam_locations = new string[] { home_dir + "/.local/share/Steam", home_dir + "/.steam/root", home_dir + "/.steam/steam", home_dir + "/.steam/debian-installation" };
            string steam_dir = steam_locations[0];
            foreach (var item in steam_locations) {
                if (Posix.opendir (item) != null) {
                    steam_dir = item + "/compatibilitytools.d";
                    break;
                }
            }

            if (Posix.opendir (steam_dir) == null) {
                Posix.mkdir (steam_dir, 0777);
            }

            locations.append (new Location ("Steam", steam_dir, ProtonPlus.Models.CompatibilityTool.Steam (), new ProtonPlus.Models.Launcher ("Steam")));
            locations.append (new Location ("Steam (Flatpak)", home_dir + "/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d", ProtonPlus.Models.CompatibilityTool.Steam (), new ProtonPlus.Models.Launcher ("Steam")));
            locations.append (new Location ("Steam (Snap)", home_dir + "/snap/steam/common/.steam/root/compatibilitytools.d", ProtonPlus.Models.CompatibilityTool.Steam (), new ProtonPlus.Models.Launcher ("Steam")));
            locations.append (new Location ("Lutris", home_dir + "/.local/share/lutris/runners/wine", ProtonPlus.Models.CompatibilityTool.Lutris (), new ProtonPlus.Models.Launcher ("Lutris")));
            locations.append (new Location ("Lutris (Flatpak)", home_dir + "/.var/app/net.lutris.Lutris/data/lutris/runners/wine", ProtonPlus.Models.CompatibilityTool.Lutris (), new ProtonPlus.Models.Launcher ("Lutris")));
            locations.append (new Location ("Lutris DXVK", home_dir + "/.local/share/lutris/runtime/dxvk", ProtonPlus.Models.CompatibilityTool.LutrisDXVK (), new ProtonPlus.Models.Launcher ("Lutris")));
            locations.append (new Location ("Lutris DXVK (Flatpak)", home_dir + "/.var/app/net.lutris.Lutris/data/lutris/runtime/dxvk", ProtonPlus.Models.CompatibilityTool.LutrisDXVK (), new ProtonPlus.Models.Launcher ("Lutris")));
            locations.append (new Location ("Heroic Wine", home_dir + "/.config/heroic/tools/wine", ProtonPlus.Models.CompatibilityTool.HeroicWine (), new ProtonPlus.Models.Launcher ("Heroic Wine")));
            locations.append (new Location ("Heroic Proton", home_dir + "/.config/heroic/tools/proton", ProtonPlus.Models.CompatibilityTool.HeroicProton (), new ProtonPlus.Models.Launcher ("Heroic Proton")));
            locations.append (new Location ("Heroic Wine (Flatpak)", home_dir + "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools/wine", ProtonPlus.Models.CompatibilityTool.HeroicWine (), new ProtonPlus.Models.Launcher ("Heroic Wine")));
            locations.append (new Location ("Heroic Proton (Flatpak)", home_dir + "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools/proton", ProtonPlus.Models.CompatibilityTool.HeroicProton (), new ProtonPlus.Models.Launcher ("Heroic Proton")));
            locations.append (new Location ("Bottles", home_dir + "/.local/share/bottles/runners", ProtonPlus.Models.CompatibilityTool.Bottles (), new ProtonPlus.Models.Launcher ("Bottles")));
            locations.append (new Location ("Bottles (Flatpak)", home_dir + "/.var/app/com.usebottles.bottles/data/bottles/runners", ProtonPlus.Models.CompatibilityTool.Bottles (), new ProtonPlus.Models.Launcher ("Bottles")));

            return locations;
        }
    }
}
