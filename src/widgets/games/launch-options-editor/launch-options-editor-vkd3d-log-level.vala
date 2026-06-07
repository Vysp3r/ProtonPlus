namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
using Gtk;

    public class LaunchOptionVKD3DLogLevel : LaunchOptionEnvCombo {
        public LaunchOptionVKD3DLogLevel () {
            string[] display_opts = {
                _ ("System Default"),
                "None (Mute logs)",
                "Error (Critical only)",
                "Warning (Errors & Warns)",
                "Fixme (Missing features)",
                "Info (General details)",
                "Trace (Verbose/Debug)"
            };

            string[] value_opts = { "", "none", "err", "warn", "fixme", "info", "trace" };

            base (
                "VKD3D_LOG_LEVEL",
                _ ("VKD3D Logging Level"),
                _ ("Adjust how much debugging information VKD3D prints to the terminal."),
                display_opts,
                value_opts
            );
        }
    }
}