namespace ProtonPlus.Utils {
    public static string safe_translate (string? str) {
        return (str != null && str != "") ? _ (str) : "";
    }

    public static string format_timestamp (string? timestamp) {
        if (timestamp == null || timestamp == "")
            return "";

        var date = new DateTime.from_iso8601 ((!) timestamp, null);
        if (date == null)
            return (!) timestamp;

        return ((!) date).to_local ().format ("%d-%m-%Y %H:%M");
    }
}
