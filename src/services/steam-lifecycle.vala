namespace ProtonPlus.Services {
    // Shared process-owned wiring. GUI restart UI is composed separately.
    public class SteamLifecycle : Object {
        public SteamSessionService sessions { get; private set; }
        public SteamRestartManager restarts { get; private set; }
        public SteamConfigurationService configuration { get; private set; }
        bool stopped = false;

        public SteamLifecycle (SteamSessionService? sessions = null,
            SteamRestartStateStore? state_store = null) {
            this.sessions = sessions ?? new SteamSessionService ();
            restarts = new SteamRestartManager (this.sessions,
                state_store ?? new SteamRestartStateStore ());
            configuration = new SteamConfigurationService (this.sessions, restarts);
            restarts.configure_configuration_reconciler (configuration);
            SteamConfigurationService.configure (configuration);
            InstallationService.instance.configure_steam_change_recorder (restarts);
            restarts.start_observation ();
        }

        public void stop () {
            if (stopped)
                return;
            stopped = true;
            restarts.stop_observation ();
            // Break the manager/configuration-service reference cycle as well
            // as the process-wide references when this process shuts down.
            restarts.configure_configuration_reconciler (null);
            InstallationService.instance.reset_lifecycle_configuration ();
            SteamConfigurationService.reset_configuration ();
        }
    }
}
