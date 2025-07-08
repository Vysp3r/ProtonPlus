namespace ProtonPlus.Globals {
	public static bool IS_STEAM_OS = false;
	public static bool IS_GAMESCOPE;
	public static bool IS_FLATPAK;
	public static GLib.List<string> HWCAPS;
	public static string PROTONTRICKS_EXEC;

	public static async void load_globals () {
		Globals.IS_FLATPAK = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);
		Globals.IS_GAMESCOPE = Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland";
		Globals.IS_STEAM_OS = (yield Utils.System.get_distribution_name ()).ascii_down () == "steamos";
		Globals.HWCAPS = Utils.System.get_hwcaps ();
		Globals.PROTONTRICKS_EXEC = yield Utils.System.get_protontricks_exec ();
	}
}