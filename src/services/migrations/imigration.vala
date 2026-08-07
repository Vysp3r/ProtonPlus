namespace ProtonPlus.Services.Migrations {

    public class MigrationContext : Object {
        public ProtonPlus.Widgets.Window? window { get; set; }

        public MigrationContext (ProtonPlus.Widgets.Window? window = null) {
            this.window = window;
        }
    }

    public interface IMigration : Object {
        public abstract string version { get; }
        public abstract async void migrate () throws GLib.Error;
        public abstract void post_migrate (MigrationContext? context = null);
    }
}
