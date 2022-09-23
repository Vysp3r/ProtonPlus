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

        public static Gtk.ListStore GetModel () {
            Gtk.ListStore model = new Gtk.ListStore (2, typeof (string), typeof (Location));
            Gtk.TreeIter iter;

            foreach (var item in GetInstallLocations ()) {
                var dir = Posix.opendir (item.InstallDirectory);

                if (dir != null) {
                    model.append (out iter);
                    model.set (iter, 0, item.Label, 1, item, -1);
                }
            }

            return model;
        }

        public static Location[] GetInstallLocations () {
            Location[] locations = new Location[11];

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

            locations[0] = new Location ("Steam", steam_dir, ProtonPlus.Models.CompatibilityTool.Steam (), new ProtonPlus.Models.Launcher ("Steam"));
            locations[1] = new Location ("Steam (Flatpak)", home_dir + "/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d", ProtonPlus.Models.CompatibilityTool.Steam (), new ProtonPlus.Models.Launcher ("Steam"));
            locations[2] = new Location ("Steam (Snap)", home_dir + "/snap/steam/common/.steam/root/compatibilitytools.d", ProtonPlus.Models.CompatibilityTool.Steam (), new ProtonPlus.Models.Launcher ("Steam"));
            locations[3] = new Location ("Lutris", home_dir + "/.local/share/lutris/runners/wine", ProtonPlus.Models.CompatibilityTool.Lutris (), new ProtonPlus.Models.Launcher ("Lutris"));
            locations[4] = new Location ("Lutris (Flatpak)", home_dir + "/.var/app/net.lutris.Lutris/data/lutris/runners/wine", ProtonPlus.Models.CompatibilityTool.Lutris (), new ProtonPlus.Models.Launcher ("Lutris"));
            locations[5] = new Location ("Heroic Wine", home_dir + "/.config/heroic/tools/wine", ProtonPlus.Models.CompatibilityTool.HeroicWine (), new ProtonPlus.Models.Launcher ("Heroic Wine"));
            locations[6] = new Location ("Heroic Proton", home_dir + "/.config/heroic/tools/proton", ProtonPlus.Models.CompatibilityTool.HeroicProton (), new ProtonPlus.Models.Launcher ("Heroic Proton"));
            locations[7] = new Location ("Heroic Wine (Flatpak)", home_dir + "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools/wine", ProtonPlus.Models.CompatibilityTool.HeroicWine (), new ProtonPlus.Models.Launcher ("Heroic Wine"));
            locations[8] = new Location ("Heroic Proton (Flatpak)", home_dir + "/.var/app/com.heroicgameslauncher.hgl/config/heroic/tools/proton", ProtonPlus.Models.CompatibilityTool.HeroicProton (), new ProtonPlus.Models.Launcher ("Heroic Proton"));
            locations[9] = new Location ("Bottles", home_dir + "/.local/share/bottles/runners", ProtonPlus.Models.CompatibilityTool.Bottles (), new ProtonPlus.Models.Launcher ("Bottles"));
            locations[10] = new Location ("Bottles (Flatpak)", home_dir + "/.var/app/com.usebottles.bottles/data/bottles/runners", ProtonPlus.Models.CompatibilityTool.Bottles (), new ProtonPlus.Models.Launcher ("Bottles"));

            return locations;
        }
    }
}
