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
    }
}
