namespace ProtonPlus.Stores {
    public class Preferences {
        public ProtonPlus.Models.Preferences.Style Style { get; set; }

        public string GetJson (bool useDefaultValue = false) {
            string json = @"{\n\t";

            if (!useDefaultValue) {
                json += @"\"" + "style" + "\" : \"" + Style.JsonValue + "\"";
            } else {
                json += @"\"style\" : \"" + "system" + "\"";
            }

            return json += "\n}";
        }
    }
}
