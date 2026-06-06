namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public enum Mode {
        NONE,
        GAMESCOPE,
        SCOPEBUDDY
    }
    public delegate void SimpleCallback ();

    public class Base : Object {
        protected SimpleCallback standard_control_changed;
        protected unowned LaunchOptionsList launch_option_handlers;

        public Base (owned SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            this.standard_control_changed = (owned) standard_control_changed;
            this.launch_option_handlers = launch_option_handlers;
        }

        internal LaunchOptionTile create_tile (string title, string subtitle, string[] tokens, bool is_advanced = false, LaunchLineType type = LaunchLineType.WRAPPER_ARGUMENT) {
            var tile = new LaunchOptionTile (title, subtitle);
            tile.toggle.notify["active"].connect (() => {
                this.standard_control_changed ();
            });

            var handler = new LaunchOptionBinding (tokens, tile.toggle, is_advanced, type);

            this.launch_option_handlers.add (handler);

            return tile;
        }

        internal LaunchOptionSpinTile create_spin_tile (string title, string subtitle, string value_label, double lower, double upper, int default_value, string env_prefix, bool is_advanced = false, LaunchLineType type = LaunchLineType.WRAPPER_ARGUMENT) {
            var tile = new LaunchOptionSpinTile (title, subtitle, value_label, lower, upper, default_value, env_prefix);
            tile.line_type = type;
            tile.toggle.notify["active"].connect (() => {
                this.standard_control_changed ();
            });

            tile.value_applied.connect (() => {
                this.standard_control_changed ();
            });

            this.launch_option_handlers.add (tile);

            return tile;
        }
    }
}