namespace ProtonPlus.Services.Migrations.Versions {

    public class v0_6_6 : Object, IMigration {
        public string version { get; default = "0.6.6"; }

        public async void migrate () {
            print ("Migration: Performing specific changes for version 0.6.6…\n");
            cleanup_legacy_flatpak_systemd_units (
                ProtonPlus.Globals.IS_FLATPAK,
                Environment.get_user_config_dir ()
            );
        }

        public static void cleanup_legacy_flatpak_systemd_units (
            bool is_flatpak,
            string user_config_dir
        ) {
            if (!is_flatpak)
                return;

            var legacy_systemd_parent = Path.build_filename (user_config_dir, "systemd");
            var legacy_systemd_dir = Path.build_filename (legacy_systemd_parent, "user");
            foreach (var unit_name in new string[] { "protonplus.service", "protonplus.timer" }) {
                var unit_path = Path.build_filename (legacy_systemd_dir, unit_name);
                if (!FileUtils.test (unit_path, FileTest.EXISTS))
                    continue;

                if (FileUtils.remove (unit_path) != 0)
                    warning ("Could not remove legacy Flatpak systemd unit: %s", unit_path);
            }

            // Remove the legacy directories only when they are empty. This
            // preserves any unrelated user systemd files that may be present.
            if (DirUtils.remove (legacy_systemd_dir) == 0)
                DirUtils.remove (legacy_systemd_parent);
        }

        public void post_migrate (MigrationContext? context = null) {
        }
    }
}
