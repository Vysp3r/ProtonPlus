namespace ProtonPlus.LaunchOptions {

    /* A selection source exposes editor state as catalog values.  It deliberately
     * has no knowledge of a GTK container or a rendered launch-command fragment. */
    public interface ILaunchCommandSelectionSource : Object {
        public abstract string option_id { get; set; }
        public abstract LaunchCommandSelection? get_selection ();
        public virtual string? get_diagnostic () { return null; }
        public virtual string get_invalid_value () { return ""; }
    }

    public class LaunchCommandStaticSelectionSource : Object, ILaunchCommandSelectionSource {
        public string option_id { get; set; }
        LaunchCommandSelection? selection;
        string? diagnostic;

        public LaunchCommandStaticSelectionSource (
            string selection_id, LaunchCommandSelection? selection = null, string? diagnostic = null
        ) {
            Object ();
            this.option_id = selection_id;
            this.selection = selection;
            this.diagnostic = diagnostic;
        }

        public LaunchCommandSelection? get_selection () { return selection; }
        public string? get_diagnostic () { return diagnostic; }
    }
}
