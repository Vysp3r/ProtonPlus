namespace ProtonPlus.Utils {
    public Json.Node? parse_json (string json) {
        try {
            return Json.from_string (json);
        } catch (Error e) {
            warning (e.message);
            return null;
        }
    }
}
