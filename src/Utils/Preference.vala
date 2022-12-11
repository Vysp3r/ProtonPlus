namespace ProtonPlus.Utils {
    public class Preference {
        public static bool Load (ref Stores.Preferences preferences) {
            try {
                GLib.File file = GLib.File.new_for_path (GLib.Environment.get_user_config_dir () + "/preferences.json");

                uint8[]  contents;
                string etag_out;
                file.load_contents (null, out contents, out etag_out);

                Json.Node node = Json.from_string ((string) contents);
                Json.Object obj = node.get_object ();

                if (!obj.has_member ("style") || !obj.has_member ("rememberLastLauncher") || !obj.has_member ("lastLauncher")) {
                    throw new GLib.Error (Quark.from_string (""), 0, "The Preferences.json is invalid. It will now be recreated.");
                }

                preferences.Style = Models.Preferences.Style.Find (obj.get_string_member ("style"));
                preferences.RememberLastLauncher = obj.get_boolean_member ("rememberLastLauncher");
                preferences.LastLauncher = obj.get_string_member ("lastLauncher");

                return true;
            } catch (GLib.IOError.NOT_FOUND e) {
                stderr.printf (e.message + "\n");
                Create (ref preferences, true);
                return Load (ref preferences);
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
                Update (ref preferences, true);
                return Load (ref preferences);
            }
        }

        public static void Apply (ref Stores.Preferences preferences) {
            Adw.StyleManager.get_default ().set_color_scheme (preferences.Style.ColorScheme);
        }

        public static void Update (ref Stores.Preferences preferences, bool useDefaultValue = false) {
            Utils.File.Delete (GLib.Environment.get_user_config_dir () + "/preferences.json");

            Create (ref preferences, useDefaultValue);
        }

        static void Create (ref Stores.Preferences preferences, bool useDefaultValue) {
            Utils.File.Write (GLib.Environment.get_user_config_dir () + "/preferences.json", preferences.GetJson (useDefaultValue));
        }
    }
}
