using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public abstract class Base : Object, ILaunchOption {
        protected unowned LaunchOptionsList launch_option_handlers;
        protected unowned LaunchOptionPresentationRegistry? presentation_registry;
        LaunchOptionCatalog catalog;
        Gee.HashMap<string, ILaunchOption> parsed_controls = new Gee.HashMap<string, ILaunchOption> ();
        public signal void changed ();
        public bool is_advanced { get; set; }
        public LaunchLineType line_type { get; set; }
        protected Gee.List<ILaunchOption> _children;

        public bool active { get; set; }
        protected virtual string backend_id { get { return ""; } }

        protected Base (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            this.launch_option_handlers = launch_option_handlers;
            this.presentation_registry = presentation_registry;
            catalog = presentation_registry != null
                ? presentation_registry.catalog : new LaunchOptionCatalog ();
            this.line_type = LaunchLineType.WRAPPER;
            this._children = new Gee.ArrayList<ILaunchOption> ();
            this.is_advanced = false;
            this.launch_option_handlers.add (this);
            this.active = false;
        }

        internal LaunchOptionTile create_tile (string id, bool is_advanced = false) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            var tile = new LaunchOptionTile (
                metadata.title, metadata.description, metadata.raw_tokens,
                is_advanced, metadata.serialization_type
            );
            tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            this.add_child (tile);
            parsed_controls.set (id, tile);
            if (presentation_registry != null)
                presentation_registry.register (id, tile, tile, false);

            return tile;
        }

        internal LaunchOptionSpinTile create_number_tile (string id, string unit, int maximum = int.MAX, int initial = 60) {
            var metadata = catalog.lookup (id);
            var tile = new LaunchOptionSpinTile (
                metadata.title, metadata.description, unit, 0, maximum, initial, metadata.raw_tokens[0] + " "
            );
            tile.line_type = metadata.serialization_type;
            tile.draft_changed.connect (() => changed ());
            add_child (tile);
            parsed_controls.set (id, tile);
            register_option (id, tile, tile);
            return tile;
        }

        internal LaunchOptionResolutionField create_resolution_tile (
            string id, bool include_auto = false, bool is_scopebuddy = false
        ) {
            var metadata = catalog.lookup (id);
            var field = new LaunchOptionResolutionField (metadata.title, metadata.description, include_auto, is_scopebuddy);
            field.draft_changed.connect (() => changed ());
            add_child (field);
            parsed_controls.set (id, field);
            register_option (id, field, field);
            return field;
        }

        internal LaunchOptionEnvCombo create_choice_tile (string id, string[] labels) {
            var metadata = catalog.lookup (id);
            var values = new Gee.ArrayList<string> ();
            values.add ("");
            values.add_all_array (metadata.semantics.selectable_values);
            var tile = new LaunchOptionEnvCombo (metadata.semantics.environment_key,
                metadata.title, metadata.description, labels, values.to_array ());
            tile.line_type = metadata.serialization_type;
            tile.changed.connect (() => changed ());
            add_child (tile);
            parsed_controls.set (id, tile);
            register_option (id, tile, tile);
            return tile;
        }

        internal LaunchOptionWrapperValueField create_value_field (string id) {
            var field = new LaunchOptionWrapperValueField (catalog.lookup (id));
            field.changed.connect (() => changed ());
            add_child (field);
            parsed_controls.set (id, field);
            register_option (id, field, field);
            return field;
        }

        void load_control (LaunchCommandOptionOccurrence occurrence) {
            var control = parsed_controls.get (occurrence.option_id);
            if (control == null)
                return;

            if (control is LaunchOptionTile) {
                ((LaunchOptionTile) control).toggle.set_active (true);
            } else if (control is LaunchOptionEnvCombo) {
                ((LaunchOptionEnvCombo) control).value = occurrence.environment_key != ""
                    ? occurrence.environment_value : occurrence.normalized_value;
            } else if (control is LaunchOptionWrapperValueField) {
                ((LaunchOptionWrapperValueField) control).text = occurrence.environment_key != ""
                    ? occurrence.environment_value : occurrence.normalized_value;
            } else if (control is LaunchOptionSpinTile) {
                ((LaunchOptionSpinTile) control).value_entry.text = occurrence.normalized_value;
            } else if (control is LaunchOptionResolutionField) {
                var resolution = (LaunchOptionResolutionField) control;
                var dimensions = occurrence.normalized_value.split (",");
                if (occurrence.environment_key != "") {
                    resolution.set_auto ();
                } else if (dimensions.length == 2) {
                    int width, height = 0;
                    if (int.try_parse (dimensions[0], out width) && int.try_parse (dimensions[1], out height))
                        resolution.set_resolution (width, height);
                }
            }
        }

        protected void register_option (string id, Gtk.Widget widget, ILaunchOption? option = null) {
            if (presentation_registry != null)
                presentation_registry.register (id, widget, option, false);
        }

        internal void load_from_parse_result (LaunchCommandParseResult parsed, string[] tokens, bool[] consumed) {
            if (backend_id == "") {
                parse_tokens (tokens, consumed);
                return;
            }

            active = false;
            foreach (var invocation in parsed.wrappers) {
                if (invocation.wrapper_id != backend_id)
                    continue;

                active = true;
                foreach (var index in invocation.executable_indexes)
                    consumed[index] = true;
                foreach (var index in invocation.argument_indexes)
                    consumed[index] = true;
                if (invocation.delimiter_index >= 0)
                    consumed[invocation.delimiter_index] = true;
                foreach (var occurrence in parsed.occurrences) {
                    if (occurrence.wrapper_id != backend_id || occurrence.is_legacy)
                        continue;
                    var first = occurrence.token_indexes[0];
                    if (!invocation.argument_indexes.contains (first)
                        && occurrence.environment_key == "")
                        continue;
                    load_control (occurrence);
                    foreach (var index in occurrence.token_indexes)
                        consumed[index] = true;
                }
                break;
            }
        }

        public void add_child (ILaunchOption child) {
            this._children.add (child);
        }

        public abstract void parse_tokens (string[] tokens, bool[] consumed);
        public abstract void clear ();
        public abstract void append_command_segments (Gee.LinkedList<string> segments);

        public bool is_active () {
            return this.active;
        }
    }
}
