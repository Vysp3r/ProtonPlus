namespace ProtonPlus.Globals {
	public static bool IS_STEAM_OS;
	public static bool IS_GAMESCOPE;
	public static bool IS_FLATPAK;
	public static GLib.List<string> HWCAPS;
	public static string DOWNLOAD_CACHE_PATH;
	public static string PROTONTRICKS_EXEC;

	public static async void load_globals () {
		Globals.IS_FLATPAK = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);
		Globals.IS_GAMESCOPE = Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland";
		Globals.IS_STEAM_OS = (yield Utils.System.get_distribution_name ()).ascii_down () == "steamos";
		Globals.HWCAPS = yield Utils.System.get_hwcaps ();
		Globals.PROTONTRICKS_EXEC = yield Utils.System.get_protontricks_exec ();
		Globals.DOWNLOAD_CACHE_PATH = "%s/ProtonPlus".printf (Environment.get_user_cache_dir ());
		if (!FileUtils.test (Globals.DOWNLOAD_CACHE_PATH, FileTest.IS_DIR))
			yield Utils.Filesystem.create_directory (Globals.DOWNLOAD_CACHE_PATH);
	}
}