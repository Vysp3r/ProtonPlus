namespace ProtonPlus {
    public static int main (string[] args) {
        if (FileUtils.test ("/.flatpak-info", FileTest.IS_REGULAR)) {
            var host_config_dir = Environment.get_variable ("HOST_XDG_CONFIG_HOME");
            if (host_config_dir == null || ((!) host_config_dir).strip () == "") {
                Environment.set_variable (
                    "HOST_XDG_CONFIG_HOME",
                    Path.build_filename (Environment.get_home_dir (), ".config"),
                    true
                );
            }
        }

        if (args.length > 1) {
            var changes_tools = CLI.changes_installed_tools (args[1]);
            Globals.load (changes_tools);
            Globals.setupLanguage ();

            ProtonPlus.Services.SteamLifecycle? steam_lifecycle = null;
            if (changes_tools) {
                ProtonPlus.Services.InstallationService.instance.configure_compatibility_process_guard (
                    new ProtonPlus.Services.CompatibilityProcessGuard.for_package (Globals.IS_FLATPAK)
                );
                var migration_manager = new ProtonPlus.Services.Migrations.Manager ();
                migration_manager.check_and_migrate_sync (Config.APP_VERSION);
                steam_lifecycle = new ProtonPlus.Services.SteamLifecycle ();
            }
            var cli = new CLI.Handler ();
            var loop = new MainLoop ();
            int result = 0;
            cli.run.begin (args, (obj, res) => {
                result = cli.run.end (res);
                loop.quit ();
            });
            loop.run ();
            if (steam_lifecycle != null)
                steam_lifecycle.stop ();
            return result;
        }

        var application = new Widgets.Application ();
        int status = application.run (args);
        return status;
    }
}
