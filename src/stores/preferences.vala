namespace ProtonPlus.Stores {
    public class Preferences {
        private static GLib.Once<Preferences> _instance;

        public static unowned Preferences instance () {
            return _instance.once (() => { return new Preferences (); });
        }

        public ProtonPlus.Models.Preference.Style CurrentStyle { get; set; }

        public ProtonPlus.Models.Location[] CustomInstallLocations { get; set; }

        public string GetJson () {
            string json = @"{\n\t";
            json += @"\"style\" : \"" + CurrentStyle.Label + "\"";
            return json += "\n}";
        }
    }
}