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
        public abstract async SteamRestartCommandResult launch_desktop_application (string desktop_id, Cancellable? cancellable);
        public abstract async SteamRestartCommandResult launch_native_fallback (Cancellable? cancellable);
        public abstract async bool delay (uint milliseconds, Cancellable? cancellable);
    }

    public class HostSteamRestartBackend : Object, SteamRestartBackend {
        private const string NATIVE_STEAM_EXECUTABLE = "/usr/bin/steam";

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
            var argv = new Gee.ArrayList<string> ();
            if (through_flatpak_host) {
                argv.add ("flatpak-spawn");
                argv.add ("--host");
            }
            argv.add (NATIVE_STEAM_EXECUTABLE);
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
            try {
                selected.launch (null, null);
                var argv = new Gee.ArrayList<string> ();
                argv.add ("gio-app:" + desktop_id);
                return new SteamRestartCommandResult (SteamRestartCommandStatus.ACCEPTED, argv, "GIO accepted the desktop application launch request; Steam startup is not yet confirmed.");
            } catch (Error e) {
                return new SteamRestartCommandResult (SteamRestartCommandStatus.FAILED, null, e.message);
            }
        }

        public async SteamRestartCommandResult launch_native_fallback (Cancellable? cancellable) {
            var argv = new Gee.ArrayList<string> ();
            argv.add (NATIVE_STEAM_EXECUTABLE);
            return yield spawn (argv, cancellable);
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
    }
}
