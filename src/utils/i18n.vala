namespace ProtonPlus.Utils {
    public static string safe_translate(string? str) {
		return (str != null && str != "") ? _(str) : "";
	}
}