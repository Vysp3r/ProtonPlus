namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

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

    /* The common toggle/binding path has no dynamic logical value. */
    class LaunchCommandFixedOptionSource : Object, ILaunchCommandSelectionSource {
        public string option_id { get; set; }
        unowned ILaunchOption option;

        public LaunchCommandFixedOptionSource (string selection_id, ILaunchOption option) {
            Object ();
            this.option_id = selection_id;
            this.option = option;
        }

        public LaunchCommandSelection? get_selection () {
            return option.is_active () ? new LaunchCommandSelection (option_id) : null;
        }
    }

    class LaunchCommandSpinSelectionSource : Object, ILaunchCommandSelectionSource {
        public string option_id { get; set; }
        unowned LaunchOptionSpinTile option;

        public LaunchCommandSpinSelectionSource (string selection_id, LaunchOptionSpinTile option) {
            Object ();
            this.option_id = selection_id;
            this.option = option;
        }

        public LaunchCommandSelection? get_selection () {
            int value = 0;
            return option.is_active () && option.try_get_value (out value)
                ? new LaunchCommandSelection (option_id, { value.to_string () }) : null;
        }

        public string? get_diagnostic () { return option.get_validation_diagnostic (); }
        public string get_invalid_value () { return option.value_entry.text; }
    }

    class LaunchCommandResolutionSelectionSource : Object, ILaunchCommandSelectionSource {
        public string option_id { get; set; }
        unowned LaunchOptionResolutionField option;

        public LaunchCommandResolutionSelectionSource (string selection_id, LaunchOptionResolutionField option) {
            Object ();
            this.option_id = selection_id;
            this.option = option;
        }

        public LaunchCommandSelection? get_selection () {
            if (!option.is_active ()) return null;
            if (option.is_auto ()) return new LaunchCommandSelection (option_id, { "auto" });
            int width, height;
            return option.try_get_resolution (out width, out height)
                ? new LaunchCommandSelection (option_id, { width.to_string (), height.to_string () }) : null;
        }

        public string? get_diagnostic () { return option.get_validation_diagnostic (); }
        public string get_invalid_value () {
            return option.width_entry.text + "\x1f" + option.height_entry.text;
        }
    }

    class LaunchCommandEnvironmentValueSource : Object, ILaunchCommandSelectionSource {
        public string option_id { get; set; }
        unowned ILaunchOption option;
        unowned LaunchOptionEnvCombo? combo;
        unowned LaunchOptionCustomPairs? pairs;

        public LaunchCommandEnvironmentValueSource (string selection_id, ILaunchOption option) {
            Object ();
            this.option_id = selection_id;
            this.option = option;
            combo = option as LaunchOptionEnvCombo;
            pairs = option as LaunchOptionCustomPairs;
        }

        public LaunchCommandSelection? get_selection () {
            if (!option.is_active ()) return null;
            if (combo != null) return new LaunchCommandSelection (option_id, { combo.value });
            if (pairs != null) {
                if (pairs.get_validation_diagnostic () != null)
                    return null;
                var value = pairs.value;
                return value == "" ? null : new LaunchCommandSelection (option_id, { value });
            }
            return null;
        }
        public string? get_diagnostic () {
            return pairs != null ? pairs.get_validation_diagnostic () : null;
        }
    }

    class LaunchCommandWrapperArgumentsSource : Object, ILaunchCommandSelectionSource {
        public string option_id { get; set; }
        unowned LaunchOptionEntryField field;
        string? diagnostic;

        public LaunchCommandWrapperArgumentsSource (string selection_id, LaunchOptionEntryField field) {
            Object ();
            this.option_id = selection_id;
            this.field = field;
        }

        public LaunchCommandSelection? get_selection () {
            string[] arguments;
            diagnostic = field.read_arguments (out arguments);
            return diagnostic == null && arguments.length > 0
                ? new LaunchCommandSelection (option_id, arguments) : null;
        }

        public string? get_diagnostic () { return diagnostic; }
        public string get_invalid_value () { return field.text; }
    }

    class LaunchCommandArgumentListSource : Object, ILaunchCommandSelectionSource {
        public string option_id { get; set; }
        unowned LaunchOptionArgumentList arguments;

        public LaunchCommandArgumentListSource (string selection_id, LaunchOptionArgumentList arguments) {
            Object ();
            option_id = selection_id;
            this.arguments = arguments;
        }

        public LaunchCommandSelection? get_selection () {
            if (arguments.get_validation_diagnostic () != null)
                return null;
            var values = arguments.get_raw_arguments ();
            return values.length > 0
                ? new LaunchCommandSelection (option_id, values, "", {}, true,
                    arguments.get_source_indexes (), arguments.get_loaded_source ()) : null;
        }

        public string? get_diagnostic () {
            return arguments.get_validation_diagnostic ();
        }

        public string get_invalid_value () {
            return string.joinv ("\x1f", arguments.get_raw_arguments ());
        }
    }

    /* Adapters are chosen by control type, never from option-ID branches. */
    public class LaunchCommandSelectionAdapterFactory : Object {
        public static ILaunchCommandSelectionSource? create (string id, Gtk.Widget? widget, ILaunchOption? option) {
            var arguments = option as LaunchOptionArgumentList;
            if (arguments != null) return new LaunchCommandArgumentListSource (id, arguments);
            var resolution = option as LaunchOptionResolutionField;
            if (resolution != null) return new LaunchCommandResolutionSelectionSource (id, resolution);
            var spin = option as LaunchOptionSpinTile;
            if (spin != null) return new LaunchCommandSpinSelectionSource (id, spin);
            var combo = option as LaunchOptionEnvCombo;
            if (combo != null) return new LaunchCommandEnvironmentValueSource (id, combo);
            var pairs = option as LaunchOptionCustomPairs;
            if (pairs != null) return new LaunchCommandEnvironmentValueSource (id, pairs);
            var field = widget as LaunchOptionEntryField;
            if (field != null) return new LaunchCommandWrapperArgumentsSource (id, field);
            if (option != null) return new LaunchCommandFixedOptionSource (id, option);
            return null;
        }
    }
}
