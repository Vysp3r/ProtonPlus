namespace ProtonPlus.Services.Migrations.Versions {
    using ProtonPlus.Utils;

    public class v0_6_0 : Object, IMigration {
        public string version { get; default = "0.6.0"; }

        public async void migrate () throws GLib.Error {
            print ("Migration: Performing specific changes for version 0.6.0…\n");

            if (!yield CacheManager.clear_cache ()) {
                throw new GLib.Error (
                    GLib.Quark.from_string ("protonplus-migration"),
                    0,
                    "Could not clear and recreate the cache directory."
                );
            }
        }

        public void post_migrate (MigrationContext? context = null) {
            if (context == null || context.window == null) {
                return;
            }

            var dialog = new ProtonPlus.Widgets.Introduction.Introduction ();
            ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, context.window);
        }
    }
}
