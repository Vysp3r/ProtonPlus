namespace ProtonPlus.Services.Migrations {

    public class Manager : GLib.Object {
        private Gee.ArrayList<IMigration?> migrations;
        private Gee.ArrayList<IMigration?> completed_migrations;

        public Manager () {
            this.migrations = new Gee.ArrayList<IMigration> ();
            this.completed_migrations = new Gee.ArrayList<IMigration> ();
            this.register_migrations ();
        }

        private void register_migrations () {
            this.migrations.add ( new Versions.v0_5_21 ());
            this.migrations.add ( new Versions.v0_6_0 ());
        }

        public async void check_and_migrate (string current_version) {
            this.completed_migrations.clear ();

            var settings = ProtonPlus.Globals.SETTINGS;

            if (settings == null) {
                print ("GSettings is not initialized. Skipping migration check.\n");
                return;
            }

            string last_version = settings.get_string ("last-version");

            if (last_version == "") {
                if (settings.get_boolean ("first-run") == false) {
                    last_version = "0.5.0";
                } else {
                    settings.set_string ("last-version", current_version);
                    return;
                }
            }

            if (last_version == current_version) {
                return;
            }

            print ("Detected version change from %s to %s. Running migration stack…\n", last_version, current_version);

            foreach (var step in this.migrations) {
                if (compare_versions (step.version, last_version) > 0 &&
                    compare_versions (step.version, current_version) <= 0) {

                    try {
                        yield step.migrate ();
                        this.completed_migrations.add (step);

                        // Keep completed migrations from running again if a later
                        // migration fails. The current version is only recorded
                        // after the entire migration stack succeeds.
                        settings.set_string ("last-version", step.version);
                    } catch (GLib.Error e) {
                        critical ("Migration failed during migration to version %s: %s", step.version, e.message);
                        return;
                    }
                }
            }

            // After successfully completing all migrations, update the version in GSettings
            settings.set_string ("last-version", current_version);
        }

        public void check_and_migrate_sync (string current_version) {
            var loop = new MainLoop ();
            this.check_and_migrate.begin (current_version, (obj, res) => {
                this.check_and_migrate.end (res);
                loop.quit ();
            });
            loop.run ();
        }

        public void post_migrate (MigrationContext? context = null) {
            foreach (var step in this.completed_migrations) {
                step.post_migrate (context);
            }
        }

        /**
         * Helper method for comparing semantic versions (X.Y.Z)
         * Returns: > 0 if v1 > v2, < 0 if v1 < v2, 0 if v1 == v2
         */
        private int compare_versions (string v1, string v2) {
            string[] parts1 = v1.split (".");
            string[] parts2 = v2.split (".");

            int max_length = int.max (parts1.length, parts2.length);

            for (int i = 0; i < max_length; i++) {
                int p1 = i < parts1.length ? int.parse (parts1[i]) : 0;
                int p2 = i < parts2.length ? int.parse (parts2[i]) : 0;

                if (p1 != p2) {
                    return p1 - p2;
                }
            }

            return 0;
        }
    }
}
