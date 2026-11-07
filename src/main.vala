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
            Globals.load ();
            Globals.setupLanguage ();
            ProtonPlus.Services.InstallationService.instance.configure_compatibility_process_guard (
                new ProtonPlus.Services.CompatibilityProcessGuard.for_package (Globals.IS_FLATPAK)
            );

            var migration_manager = new ProtonPlus.Services.Migrations.Manager ();
            migration_manager.check_and_migrate_sync (Config.APP_VERSION);

            ProtonPlus.Services.SteamLifecycle? steam_lifecycle = null;
            var command = args[1];
            if (command == "install" || command == "uninstall" || command == "update") {
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
            else
                ProtonPlus.Services.InstallationService.instance.reset_lifecycle_configuration ();
            return result;
        }

        var application = new Widgets.Application ();
        int status = application.run (args);
        return status;
    }
}
