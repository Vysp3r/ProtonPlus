namespace ProtonPlus.Manager {
    public class Preferences {
        public static bool Load (ref Stores.Preferences preferences) {
            try {
                GLib.File file = GLib.File.new_for_path (GLib.Environment.get_user_config_dir () + "/preferences.json");

                uint8[]  contents;
                string etag_out;
                file.load_contents (null, out contents, out etag_out);

                Json.Node node = Json.from_string ((string) contents);
                Json.Object obj = node.get_object ();

                preferences.Style = Models.Preferences.Style.Find (obj.get_string_member ("style"));

                return true;
            } catch (GLib.IOError.NOT_FOUND e) {
                stderr.printf (e.message);
                Create (ref preferences, true);
                return Load (ref preferences);
            } catch (GLib.Error e) {
                stderr.printf (e.message);
                return false;
            }
        }

        public static void Apply (ref Stores.Preferences preferences) {
            Adw.StyleManager.get_default ().set_color_scheme (preferences.Style.ColorScheme);
        }

        public static void Update (ref Stores.Preferences preferences) {
            Manager.File.Delete (GLib.Environment.get_user_config_dir () + "/preferences.json");

            Create (ref preferences, false);
        }

        static void Create (ref Stores.Preferences preferences, bool useDefaultValue) {
            Manager.File.Write (GLib.Environment.get_user_config_dir () + "/preferences.json", preferences.GetJson (useDefaultValue));
        }
    }
}
