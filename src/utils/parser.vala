namespace ProtonPlus.Utils {
    public class Parser {
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