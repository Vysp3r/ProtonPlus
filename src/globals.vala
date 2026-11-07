namespace ProtonPlus.Globals {
    public static Settings SETTINGS;
    public static bool IS_STEAM_OS;
    public static bool IS_FLATPAK;
    public static Models.CpuCapabilities CPU_CAPABILITIES;
    public static List<string> HWCAPS;
    public static string CACHE_PATH;
    public static bool PROTONTRICKS_INSTALLED;
    public static bool PROTONTRICKS_FLATPAK_INSTALLED;
    public static bool FAUGUS_FLATPAK_INSTALLED;
    public static bool MANGOHUD_INSTALLED;
    public static bool MANGOHUD_FLATPAK_INSTALLED;
    public static bool GAMESCOPE_INSTALLED;
    public static bool SCOPEBUDDY_INSTALLED;
    public static bool GAMEMODE_INSTALLED;
    public static bool GAME_PERFORMANCE_INSTALLED;
    public static bool OBS_VKCAPTURE_INSTALLED;
    public static bool OBS_VKCAPTURE_FLATPAK_INSTALLED;
    public static bool OBS_VKCAPTURE_FLATPAK_PLUGIN_INSTALLED;
    public static bool VKBASALT_INSTALLED;
    private static bool loaded = false;

    public struct LanguageItem {
        public string code;
        public string name;
        public int index;
    }

    public static LanguageItem[] LANGUAGES () {
        return new LanguageItem[] {
                   { "system", _("System"), 0 },
                   { "ar", _("Arabic"), 1 },
                   { "be", _("Belarusian"), 2 },
                   { "bs", _("Bosnian"), 3 },
                   { "cs", _("Czech"), 4 },
                   { "de", _("German"), 5 },
                   { "en", _("English"), 6 },
                   { "el", _("Greek"), 7 },
                   { "es", _("Spanish"), 8 },
                   { "fi", _("Finnish"), 9 },
                   { "fr", _("French"), 10 },
                   { "hr", _("Croatian"), 11 },
                   { "id", _("Indonesian"), 12 },
                   { "it", _("Italian"), 13 },
                   { "ja", _("Japanese"), 14 },
                   { "ka", _("Georgian"), 15 },
                   { "nl", _("Dutch"), 16 },
                   { "pl", _("Polish"), 17 },
                   { "pt", _("Portuguese (Portugal)"), 18 },
                   { "ru", _("Russian"), 19 },
                   { "sr@latin", _("Serbian (Latin)"), 20 },
                   { "sk", _("Slovak"), 26 },
                   { "sv", _("Swedish"), 21 },
                   { "uk", _("Ukrainian"), 22 },
                   { "vi", _("Vietnamese"), 23 },
                   { "zh-CN", _("Chinese"), 24 },
                   { "zh-TW", _("Chinese (Traditional)"), 25 }
        };
    }

    public static void setupLanguage () {
        string current_locale = "";

        if (Globals.SETTINGS != null) {
            int saved_enum_value = Globals.SETTINGS.get_enum ("language");

            foreach (var language in LANGUAGES ()) {
                if (language.index == saved_enum_value) {
                    current_locale = language.code;
                    break;
                }
            }
        }

        if (current_locale == "system" || current_locale == "") {
            Environment.unset_variable ("LANGUAGE");
            current_locale = "";
        } else {
            Environment.set_variable ("LANGUAGE", current_locale, true);
        }

        Intl.setlocale (LocaleCategory.ALL, current_locale);
        Intl.setlocale (LocaleCategory.MESSAGES, current_locale);

        Intl.bindtextdomain (Config.APP_ID, Environment.get_variable ("LOCALE_DIR") ?? Config.LOCALE_DIR);
        Intl.bind_textdomain_codeset (Config.APP_ID, "UTF-8");
        Intl.textdomain (Config.APP_ID);
    }

    public static void load () {
        if (loaded)
            return;

        loaded = true;

        var schema_source = SettingsSchemaSource.get_default ();

        if (schema_source != null && SETTINGS == null) {
            var schema = schema_source.lookup ("com.vysp3r.ProtonPlus.State", true);

            if (schema != null && Utils.Filesystem.is_valid_schema (schema)) {
                SETTINGS = new Settings.full (schema, null, null);
            }
        }

        Globals.IS_FLATPAK = FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR);

        Globals.IS_STEAM_OS = Utils.System.get_distribution_name ().ascii_down () == "steamos";

        Globals.CPU_CAPABILITIES = Utils.System.get_cpu_capabilities ();
        Globals.HWCAPS = Utils.System.get_hwcaps_for_capabilities (Globals.CPU_CAPABILITIES);

        var components = new Utils.InstalledComponents (Globals.IS_FLATPAK);
        Globals.PROTONTRICKS_INSTALLED = components.protontricks;
        Globals.PROTONTRICKS_FLATPAK_INSTALLED = components.has_flatpak ("com.github.Matoking.protontricks");
        Globals.FAUGUS_FLATPAK_INSTALLED = components.has_flatpak (
            Models.Launchers.FaugusLauncher.FLATPAK_ID
        );

        Globals.MANGOHUD_INSTALLED = components.mangohud;
        Globals.MANGOHUD_FLATPAK_INSTALLED = components.has_flatpak ("org.freedesktop.Platform.VulkanLayer.MangoHud");
        Globals.GAMESCOPE_INSTALLED = components.gamescope;
        Globals.GAMEMODE_INSTALLED = components.gamemode;
        Globals.GAME_PERFORMANCE_INSTALLED = components.game_performance;
        Globals.OBS_VKCAPTURE_INSTALLED = components.obs_vkcapture;
        Globals.OBS_VKCAPTURE_FLATPAK_INSTALLED = components.has_flatpak (
            "org.freedesktop.Platform.VulkanLayer.OBSVkCapture"
        );
        Globals.OBS_VKCAPTURE_FLATPAK_PLUGIN_INSTALLED = components.has_flatpak (
            "com.obsproject.Studio.Plugin.OBSVkCapture"
        );
        Globals.SCOPEBUDDY_INSTALLED = components.scopebuddy;
        Globals.VKBASALT_INSTALLED = components.vkbasalt;

        Globals.CACHE_PATH = Path.build_filename (Environment.get_user_cache_dir (), "ProtonPlus");
        if (!FileUtils.test (Globals.CACHE_PATH, FileTest.IS_DIR)) {
            Utils.Filesystem.create_directory (Globals.CACHE_PATH);
        }
    }
}
