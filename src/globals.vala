namespace ProtonPlus.Globals {
    public static Settings SETTINGS;
    public static bool IS_STEAM_OS;
    public static bool IS_GAMESCOPE;
    public static bool IS_FLATPAK;
    public static List<string> HWCAPS;
    public static string CACHE_PATH;
    public static string PROTONTRICKS_EXEC;
    public static string CONFIG_PATH;

    public static void load () {
        var schema_source = SettingsSchemaSource.get_default ();

        if (schema_source != null) {
            var schema = schema_source.lookup ("com.vysp3r.ProtonPlus.State", true);

            if (schema != null &&
                schema.has_key ("width") &&
                schema.has_key ("height") &&
                schema.has_key ("is-maximized") &&
                schema.has_key ("is-fullscreen") &&
                schema.has_key ("automatic-updates") &&
                schema.has_key ("github-api-key") &&
                schema.has_key ("gitlab-api-key") &&
                schema.has_key ("steam-last-profile-id") &&
                schema.has_key ("steam-remember-last-profile") &&
                schema.has_key ("save-history") &&
                schema.has_key ("first-run") &&
                schema.has_key ("experimental-mode") &&
                schema.has_key ("theme"))
                SETTINGS = new Settings.full (schema, null, null);
        }

        Globals.IS_FLATPAK = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);

        Globals.IS_GAMESCOPE = Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland";

        Globals.IS_STEAM_OS = Utils.System.get_distribution_name ().ascii_down () == "steamos";

        Globals.HWCAPS = Utils.System.get_hwcaps ();

        Globals.PROTONTRICKS_EXEC = Utils.System.get_protontricks_exec_sync ();

        Globals.CACHE_PATH = "%s/ProtonPlus".printf (Environment.get_user_cache_dir ());
        if (!FileUtils.test (Globals.CACHE_PATH, FileTest.IS_DIR))
        Utils.Filesystem.create_directory (Globals.CACHE_PATH);

        Globals.CONFIG_PATH = "%s/ProtonPlus".printf (Environment.get_user_config_dir ());
        if (!FileUtils.test (Globals.CONFIG_PATH, FileTest.IS_DIR))
        Utils.Filesystem.create_directory (Globals.CONFIG_PATH);
    }


}