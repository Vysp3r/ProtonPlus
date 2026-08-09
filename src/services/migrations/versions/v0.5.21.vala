namespace ProtonPlus.Services.Migrations.Versions {

    public class v0_5_21 : Object, IMigration {
        public string version { get; default = "0.5.21"; }

        public async void migrate () {
            print ("Migration: Performing specific changes for version 0.5.21…\n");
        }

        public void post_migrate (MigrationContext? context = null) {
        }
    }
}
