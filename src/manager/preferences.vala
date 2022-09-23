namespace ProtonPlus.Manager {
    public class Preferences {
        public static void Load() {
            ProtonPlus.Stores.Preferences store = ProtonPlus.Stores.Preferences.instance();
            try {
                GLib.File file = GLib.File.new_for_path(GLib.Environment.get_user_config_dir() + "/preferences.json");

                uint8[]  contents;
                string etag_out;
                file.load_contents(null, out contents, out etag_out);

                Json.Node node = Json.from_string((string) contents);
                Json.Object obj = node.get_object();

                store.CurrentStyle = Models.Preference.FindStyle(obj.get_string_member("style"));
            } catch (GLib.IOError.NOT_FOUND e) {
                Create();
                Load();
            }
            Apply();
        }

        public static void Apply() {
            ProtonPlus.Stores.Preferences store = ProtonPlus.Stores.Preferences.instance();
            Adw.StyleManager.get_default().set_color_scheme(store.CurrentStyle.ColorScheme);
        }

        public static void Update() {
            GLib.File file = GLib.File.new_for_path(GLib.Environment.get_user_config_dir() + "/preferences.json");
            file.delete ();
            Create();
        }

        private static void Create() {
            GLib.File file = GLib.File.new_for_path(GLib.Environment.get_user_config_dir() + "/preferences.json");
            FileOutputStream os = file.create(FileCreateFlags.PRIVATE);

            ProtonPlus.Stores.Preferences store = ProtonPlus.Stores.Preferences.instance();

            os.write(store.GetJson().data);
        }
    }
}
