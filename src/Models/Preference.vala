using Models.Preferences;

namespace Models {
    public class Preference {
        public Style Style { get; set; }
        public bool RememberLastLauncher { get; set; }
        public string LastLauncher { get; set; }

        public Preference () {
        }

        public string GetJson (bool useDefaultValue = false) {
            string json = @"{\n\t";

            if (!useDefaultValue) {
                json += @"\"" + "style" + "\" : \"" + Style.JsonValue + "\",\n";
                json += @"\t\"" + "rememberLastLauncher" + "\" : " + RememberLastLauncher.to_string () + ",\n";
                json += @"\t\"" + "lastLauncher" + "\" : \"" + LastLauncher + "\"";
            } else {
                json += @"\"style\" : \"" + "system" + "\",\n";
                json += @"\t\"" + "rememberLastLauncher" + "\" : true,\n";
                json += @"\t\"" + "lastLauncher" + "\" : \"\"";
            }

            json += "\n}";
            return json;
        }
    }
}
