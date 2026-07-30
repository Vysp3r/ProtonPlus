namespace ProtonPlus {
    public static int main (string[] args) {
        if (args.length > 1) {
            Globals.load ();
            Globals.setupLanguage ();
            Notify.init (Config.APP_NAME);

            var migration_manager = new ProtonPlus.Services.Migrations.Manager ();
            migration_manager.check_and_migrate_sync (Config.APP_VERSION);

            ProtonPlus.Services.SteamRestartManager? steam_restart_manager = null;
            var command = args[1];
            if (command == "install" || command == "uninstall" || command == "update") {
                var session_service = new ProtonPlus.Services.SteamSessionService ();
                steam_restart_manager = new ProtonPlus.Services.SteamRestartManager (
                    session_service, new ProtonPlus.Services.SteamRestartStateStore ()
                );
                var configuration_service = new ProtonPlus.Services.SteamConfigurationService (
                    session_service, (!) steam_restart_manager
                );
                ((!) steam_restart_manager).configure_configuration_reconciler (configuration_service);
                ProtonPlus.Services.SteamConfigurationService.configure (configuration_service);
                ProtonPlus.Services.InstallationService.instance.configure_steam_change_recorder ((!) steam_restart_manager);
                steam_restart_manager.start_observation ();
            }
            var cli = new CLI.Handler ();
            var loop = new MainLoop ();
            int result = 0;
            cli.run.begin (args, (obj, res) => {
                result = cli.run.end (res);
                loop.quit ();
            });
            loop.run ();
            if (steam_restart_manager != null)
                steam_restart_manager.stop_observation ();
            ProtonPlus.Services.InstallationService.instance.reset_lifecycle_configuration ();
            ProtonPlus.Services.SteamConfigurationService.reset_configuration ();
            Notify.uninit ();
            return result;
        }

        var application = new Widgets.Application ();
        int status = application.run (args);
        return status;
    }
}
