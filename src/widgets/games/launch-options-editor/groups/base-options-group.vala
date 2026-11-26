using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class BaseOptionsGroup : PreferencesGroup {
        protected unowned LaunchOptionsList launch_option_handlers;
        protected unowned LaunchOptionPresentationRegistry? presentation_registry;
        protected bool presentation_movable;
        LaunchOptionCatalog catalog;
        public signal void changed ();
        internal bool is_advanced_group { get; set; default = false; }

        public BaseOptionsGroup (
            LaunchOptionsList launch_option_handlers,
            bool is_advanced_group = false,
            LaunchOptionPresentationRegistry? presentation_registry = null,
            bool presentation_movable = true
        ) {
            this.launch_option_handlers = launch_option_handlers;
            this.is_advanced_group = is_advanced_group;
            this.presentation_registry = presentation_registry;
            this.presentation_movable = presentation_movable;
            catalog = presentation_registry != null
                ? presentation_registry.catalog : new LaunchOptionCatalog ();
        }

        internal LaunchOptionTile create_tile (string id, bool is_advanced = false) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            // Recognition tokens can include an old off/on pair. The writer
            // continues to own canonical emission through catalog semantics.
            var tile = new LaunchOptionTile (
                metadata.title, metadata.description, metadata.raw_tokens,
                is_advanced, metadata.serialization_type
            );
            tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            this.launch_option_handlers.add (tile);
            if (presentation_registry != null)
                presentation_registry.register (id, tile, tile, presentation_movable);

            return tile;
        }

        internal LaunchOptionEnvironmentField create_environment_field (string id) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            var field = new LaunchOptionEnvironmentField (metadata);
            field.changed.connect (() => changed ());
            launch_option_handlers.add (field);
            register_option (id, field, field);
            return field;
        }

        internal LaunchOptionEnvCombo create_environment_combo (string id, string[] labels = {}) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            var choices = metadata.semantics.selectable_values;
            assert (labels.length == 0 || labels.length == choices.length);
            var display = new string[choices.length + 1];
            var values = new string[choices.length + 1];
            display[0] = _("Default");
            values[0] = "";
            for (var index = 0; index < choices.length; index++) {
                display[index + 1] = labels.length == 0 ? choices[index] : labels[index];
                values[index + 1] = choices[index];
            }
            var combo = new LaunchOptionEnvCombo (metadata.semantics.environment_key,
                metadata.title, metadata.description, display, values);
            combo.changed.connect (() => changed ());
            launch_option_handlers.add (combo);
            register_option (id, combo, combo);
            return combo;
        }

        internal LaunchOptionSpinTile create_spin_tile (
            string id,
            string value_label,
            int lower,
            int upper,
            int default_value
        ) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            var tile = new LaunchOptionSpinTile (metadata.title, metadata.description, value_label,
                lower, upper, default_value, metadata.raw_tokens[0]);
            tile.line_type = metadata.serialization_type;
            tile.draft_changed.connect (() => this.changed ());

            this.launch_option_handlers.add (tile);
            register_option (id, tile, tile);

            return tile;
        }

        protected void register_option (string id, Gtk.Widget widget, ILaunchOption? option = null) {
            if (presentation_registry != null)
                presentation_registry.register (id, widget, option, presentation_movable);
        }

        public bool matches_search (string query) {
            if (query == "")
                return true;

            if (text_matches (this.title, query) || text_matches (this.description, query))
                return true;

            for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
                var row = child as PreferencesRow;
                var action_row = child as ActionRow;
                if (row != null && text_matches (row.title, query))
                    return true;
                if (action_row != null && text_matches (action_row.subtitle, query))
                    return true;
            }

            return false;
        }

        bool text_matches (string? text, string query) {
            return text != null && text.down ().contains (query);
        }

        public virtual bool has_advanced_active () {
            return this.is_advanced_group;
        }
    }
}
