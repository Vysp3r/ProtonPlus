namespace ProtonPlus.Utils {
    public string bytes_to_string (uint8[] data) {
        if (data.length == 0)
            return "";

        return ((string) data).substring (0, data.length);
    }
}
