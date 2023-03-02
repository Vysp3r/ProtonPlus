namespace Utils {
    public class Preference {
        public static bool Load (Models.Preference preference) {
            try {
                GLib.File file = GLib.File.new_for_path (GLib.Environment.get_user_config_dir () + "/preferences.json");

                uint8[] contents;
                string etag_out;
                file.load_contents (null, out contents, out etag_out);

                Json.Node node = Json.from_string ((string) contents);
                Json.Object obj = node.get_object ();

                if (!obj.has_member ("style") || !obj.has_member ("rememberLastLauncher") || !obj.has_member ("lastLauncher") || !obj.has_member ("gamescopewarning")) {
                    throw new GLib.Error (Quark.from_string (""), 0, "The Preferences.json is invalid. It will now be recreated.");
                }

                preference.Style = Models.Preferences.Style.Find (obj.get_string_member ("style"));
                preference.RememberLastLauncher = obj.get_boolean_member ("rememberLastLauncher");
                preference.LastLauncher = obj.get_string_member ("lastLauncher");
                preference.GamescopeWarning = obj.get_boolean_member ("gamescopewarning");

                return true;
            } catch (GLib.IOError.NOT_FOUND e) {
                stderr.printf (e.message + "\n");
                Create (preference, true);
                return Load (preference);
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
                Update (preference, true);
                return Load (preference);
            }
        }

        public static void Apply (Models.Preference preference) {
            Adw.StyleManager.get_default ().set_color_scheme (preference.Style.ColorScheme);
        }

        public static void Update (Models.Preference preference, bool useDefaultValue = false) {
            var dir = new Utils.DirUtil(GLib.Environment.get_user_config_dir ());
            dir.remove_file("preferences.json");

            Create (preference, useDefaultValue);
        }

        static void Create (Models.Preference preference, bool useDefaultValue) {
            Utils.File.Write (GLib.Environment.get_user_config_dir () + "/preferences.json", preference.GetJson (useDefaultValue));
        }
    }
}
