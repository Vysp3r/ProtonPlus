namespace ProtonPlus.Utils {
    public class Parser {
        public static string data_to_string (uint8[] data) {
            if (data.length == 0)
                return "";

            return ((string) data).substring (0, data.length);
        }

        public static Json.Node? get_node_from_json (string json) {
            try {
                return Json.from_string (json);
            } catch (Error e) {
                warning (e.message);
                return null;
            }
        }
    }
}
