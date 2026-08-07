namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    public enum SteamRestartCommandStatus {
        ACCEPTED,
        UNAVAILABLE,
        FAILED,
        CANCELLED
    }

    /* Command acceptance is deliberately weaker than lifecycle confirmation. */
    public class SteamRestartCommandResult : Object {
        public SteamRestartCommandStatus status { get; private set; }
        public Gee.List<string> argv { get; private set; }
        public string diagnostic { get; private set; }

        public SteamRestartCommandResult (SteamRestartCommandStatus status, Gee.List<string>? argv = null, string diagnostic = "") {
            this.status = status;
            this.argv = argv ?? new Gee.ArrayList<string> ();
            this.diagnostic = diagnostic;
        }
    }

    /* The orchestrator never builds a shell string.  This is also the single
     * fixture seam for command dispatch and asynchronous polling delays. */
    public interface SteamRestartBackend : Object {
        public abstract bool has_desktop_application (string desktop_id);
        public abstract bool has_native_fallback ();
        public abstract async SteamRestartCommandResult request_native_shutdown (bool through_flatpak_host, Cancellable? cancellable);
        public abstract async SteamRestartCommandResult request_flatpak_shutdown (bool through_flatpak_host, Cancellable? cancellable);
        public abstract async SteamRestartCommandResult launch_desktop_application (string desktop_id, Cancellable? cancellable);
        public abstract async SteamRestartCommandResult launch_native_fallback (Cancellable? cancellable);
        public abstract async bool delay (uint milliseconds, Cancellable? cancellable);
    }

    /* A narrow construction seam keeps the trusted argv policy in the host
     * backend while allowing the non-blocking launch contract to be tested
     * without executing Steam. */
    public interface SteamRestartProcessFactory : Object {
        public abstract Subprocess spawn_detached (string[] argv) throws Error;
    }

    public class HostSteamRestartProcessFactory : Object, SteamRestartProcessFactory {
        public Subprocess spawn_detached (string[] argv) throws Error {
            var launcher = new SubprocessLauncher (
                SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE
            );
            launcher.set_stdin_file_path ("/dev/null");
            launcher.set_child_setup (detach_child_session);
            return launcher.spawnv (argv);
        }

        private static void detach_child_session () {
            if (Posix.setsid () < 0)
                Posix._exit (127);
        }
    }

    public class HostSteamRestartBackend : Object, SteamRestartBackend {
        private const string NATIVE_STEAM_EXECUTABLE = "/usr/bin/steam";
        private SteamRestartProcessFactory process_factory;

        public HostSteamRestartBackend (SteamRestartProcessFactory? process_factory = null) {
            this.process_factory = process_factory ?? new HostSteamRestartProcessFactory ();
        }

        public bool has_desktop_application (string desktop_id) {
            foreach (var app in AppInfo.get_all ()) {
                if (app.get_id () == desktop_id)
                    return true;
            }
            return false;
        }

        public bool has_native_fallback () {
            return FileUtils.test (NATIVE_STEAM_EXECUTABLE, FileTest.IS_EXECUTABLE);
        }

        public async SteamRestartCommandResult request_native_shutdown (bool through_flatpak_host, Cancellable? cancellable) {
            return yield spawn (build_native_shutdown_argv (through_flatpak_host), cancellable);
        }

        public static Gee.List<string> build_native_shutdown_argv (bool through_flatpak_host) {
            var argv = new Gee.ArrayList<string> ();
            if (through_flatpak_host) {
                argv.add ("flatpak-spawn");
                argv.add ("--host");
            }
            argv.add (NATIVE_STEAM_EXECUTABLE);
            argv.add ("-shutdown");
            return argv;
        }

        public async SteamRestartCommandResult request_flatpak_shutdown (bool through_flatpak_host, Cancellable? cancellable) {
            /* The Flathub Steam wrapper forwards its arguments to Steam, so the
             * client's own shutdown request remains graceful.  Never substitute
             * flatpak kill here: it force-terminates the sandbox. */
            var argv = new Gee.ArrayList<string> ();
            if (through_flatpak_host) {
                argv.add ("flatpak-spawn");
                argv.add ("--host");
            }
            argv.add ("flatpak");
            argv.add ("run");
            argv.add ("com.valvesoftware.Steam");
            argv.add ("-shutdown");
            return yield spawn (argv, cancellable);
        }

        public async SteamRestartCommandResult launch_desktop_application (string desktop_id, Cancellable? cancellable) {
            if (cancellable != null && cancellable.is_cancelled ())
                return new SteamRestartCommandResult (SteamRestartCommandStatus.CANCELLED, null, "Launch was cancelled before desktop application resolution.");
            AppInfo? selected = null;
            foreach (var app in AppInfo.get_all ()) {
                if (app.get_id () == desktop_id) {
                    selected = app;
                    break;
                }
            }
            if (selected == null)
                return new SteamRestartCommandResult (SteamRestartCommandStatus.UNAVAILABLE, null, "Expected desktop application was not available through GIO: %s".printf (desktop_id));
            var desktop = selected as DesktopAppInfo;
            if (desktop == null)
                return new SteamRestartCommandResult (SteamRestartCommandStatus.UNAVAILABLE, null,
                    "Expected application is not backed by a desktop entry: %s".printf (desktop_id));
            try {
                var uris = new List<string> ();
                desktop.launch_uris_as_manager (
                    uris, null,
                    SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL,
                    detach_child_session
                );
                var argv = new Gee.ArrayList<string> ();
                argv.add ("gio-app:" + desktop_id);
                return new SteamRestartCommandResult (SteamRestartCommandStatus.ACCEPTED, argv, "GIO accepted the detached desktop application launch request; Steam startup is not yet confirmed.");
            } catch (Error e) {
                return new SteamRestartCommandResult (SteamRestartCommandStatus.FAILED, null, e.message);
            }
        }

        public async SteamRestartCommandResult launch_native_fallback (Cancellable? cancellable) {
            var argv = new Gee.ArrayList<string> ();
            argv.add (NATIVE_STEAM_EXECUTABLE);
            return yield spawn_detached (argv, cancellable);
        }

        public async bool delay (uint milliseconds, Cancellable? cancellable) {
            if (cancellable != null && cancellable.is_cancelled ())
                return false;
            if (milliseconds == 0)
                return cancellable == null || !cancellable.is_cancelled ();
            uint source_id = 0;
            ulong cancellation_handler_id = 0;
            source_id = Timeout.add (milliseconds, () => {
                source_id = 0;
                if (cancellable != null && cancellation_handler_id != 0) {
                    cancellable.disconnect (cancellation_handler_id);
                    cancellation_handler_id = 0;
                }
                delay.callback ();
                return Source.REMOVE;
            });
            if (cancellable != null) {
                cancellation_handler_id = cancellable.cancelled.connect (() => {
                    if (source_id == 0)
                        return;
                    Source.remove (source_id);
                    source_id = 0;
                    delay.callback ();
                });
            }
            yield;
            if (cancellable != null && cancellation_handler_id != 0)
                cancellable.disconnect (cancellation_handler_id);
            return cancellable == null || !cancellable.is_cancelled ();
        }

        private async SteamRestartCommandResult spawn (Gee.List<string> argv, Cancellable? cancellable) {
            if (cancellable != null && cancellable.is_cancelled ())
                return new SteamRestartCommandResult (SteamRestartCommandStatus.CANCELLED, argv, "Command was cancelled before dispatch.");
            var values = new string[argv.size];
            for (var i = 0; i < argv.size; i++)
                values[i] = argv[i];
            try {
                var subprocess = new Subprocess.newv (values, SubprocessFlags.NONE);
                yield subprocess.wait_async (cancellable);
                if (cancellable != null && cancellable.is_cancelled ())
                    return new SteamRestartCommandResult (SteamRestartCommandStatus.CANCELLED, argv, "Command wait was cancelled after dispatch.");
                if (!subprocess.get_successful ())
                    return new SteamRestartCommandResult (SteamRestartCommandStatus.FAILED, argv, "Command exited unsuccessfully (%d).".printf (subprocess.get_exit_status ()));
                return new SteamRestartCommandResult (SteamRestartCommandStatus.ACCEPTED, argv, "Command completed; lifecycle state still requires observation.");
            } catch (Error e) {
                return new SteamRestartCommandResult (SteamRestartCommandStatus.FAILED, argv, e.message);
            }
        }

        /* Steam is a long-running GUI process.  Dispatch is intentionally not
         * coupled to its lifetime; the orchestrator confirms startup through
         * SteamSessionService.  GSubprocess reaps the child when it exits. */
        private async SteamRestartCommandResult spawn_detached (Gee.List<string> argv, Cancellable? cancellable) {
            if (cancellable != null && cancellable.is_cancelled ())
                return new SteamRestartCommandResult (SteamRestartCommandStatus.CANCELLED, argv, "Launch was cancelled before dispatch.");
            var values = new string[argv.size];
            for (var i = 0; i < argv.size; i++)
                values[i] = argv[i];
            try {
                process_factory.spawn_detached (values);
                return new SteamRestartCommandResult (SteamRestartCommandStatus.ACCEPTED, argv, "Detached launch was dispatched; Steam startup is not yet confirmed.");
            } catch (Error e) {
                return new SteamRestartCommandResult (SteamRestartCommandStatus.FAILED, argv, e.message);
            }
        }

        private static void detach_child_session () {
            if (Posix.setsid () < 0)
                Posix._exit (127);
        }
    }
}
