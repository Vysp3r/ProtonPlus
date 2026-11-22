namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    /* Owns the editor's baseline and reset intent. UI controls expose current
     * selections, but dirty tracking and full-source replacement live here so
     * preview and persistence cannot disagree about what changed. */
    public class LaunchCommandEditState : Object {
        HashMap<string, string> baseline_selections;
        ArrayList<string> modified_option_ids;

        public bool explicit_clear { get; private set; default = false; }
        public bool is_dirty { get { return explicit_clear || modified_option_ids.size > 0; } }

        public LaunchCommandEditState () {
            baseline_selections = new HashMap<string, string> ();
            modified_option_ids = new ArrayList<string> ();
        }

        public void record_baseline (Collection<ILaunchCommandSelectionSource> sources) {
            baseline_selections.clear ();
            modified_option_ids.clear ();
            explicit_clear = false;
            foreach (var source in sources)
                baseline_selections.set (source.option_id, source_fingerprint (source));
        }

        public void update (Collection<ILaunchCommandSelectionSource> sources) {
            modified_option_ids.clear ();
            foreach (var source in sources) {
                var original = baseline_selections.has_key (source.option_id)
                    ? baseline_selections.get (source.option_id) : "";
                if (source_fingerprint (source) != original
                    && !modified_option_ids.contains (source.option_id))
                    modified_option_ids.add (source.option_id);
            }
        }

        /* Clear starts a replacement edit. Subsequent control changes must
         * continue building from an empty source instead of merging the old
         * command back into the result. */
        public void mark_explicit_clear (Collection<ILaunchCommandSelectionSource> sources) {
            update (sources);
            explicit_clear = true;
        }

        public string[] get_modified_option_ids () {
            return modified_option_ids.to_array ();
        }

        public bool is_option_modified (string option_id) {
            return modified_option_ids.contains (option_id);
        }

        static string source_fingerprint (ILaunchCommandSelectionSource source) {
            var selection = source.get_selection ();
            if (selection == null)
                return source.get_diagnostic () != null ? "invalid:" + source.get_invalid_value () : "";
            var values = selection.get_values ();
            var fingerprint = new StringBuilder ();
            fingerprint.append_printf ("%s\x1f%s\x1f", selection.option_id, selection.wrapper_id);
            for (var index = 0; index < values.length; index++)
                fingerprint.append_printf ("%d:%d:%s", selection.get_value_source_index (index),
                    values[index].length, values[index]);
            foreach (var argument in selection.get_additional_wrapper_arguments ())
                fingerprint.append_printf ("%d:%s", argument.length, argument);
            return fingerprint.str;
        }
    }
}
