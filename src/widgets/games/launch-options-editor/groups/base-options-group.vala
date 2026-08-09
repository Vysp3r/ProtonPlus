namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class BaseOptionsGroup : PreferencesGroup {
        protected unowned LaunchOptionsList launch_option_handlers;
        protected unowned LaunchOptionPresentationRegistry? presentation_registry;
        protected bool presentation_movable;
        public signal void changed ();
        public signal void advanced_changed ();

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
        }

        internal LaunchOptionTile create_game_argument_tile (
            string title, string subtitle, string[] tokens, bool is_advanced = false, string id = ""
        ) {
            return create_tile (title, subtitle, tokens, is_advanced, LaunchLineType.ARGUMENT, id);
        }

        internal LaunchOptionTile create_tile (
            string title,
            string subtitle,
            string[] tokens,
            bool is_advanced = false,
            LaunchLineType type = LaunchLineType.ENVIRONMENT,
            string id = ""
        ) {
            var tile = new LaunchOptionTile (title, subtitle, tokens, is_advanced, type);
            tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            this.launch_option_handlers.add (tile);
            if (id != "" && presentation_registry != null)
                presentation_registry.register (id, tile, tile, presentation_movable);

            return tile;
        }

        internal LaunchOptionSpinTile create_spin_tile (
            string title,
            string subtitle,
            string value_label,
            double lower,
            double upper,
            int default_value,
            string env_prefix,
            bool is_advanced = false,
            LaunchLineType type = LaunchLineType.ENVIRONMENT,
            string id = ""
        ) {
            var tile = new LaunchOptionSpinTile (title, subtitle, value_label, lower, upper, default_value, env_prefix);
            tile.line_type = type;
            tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            tile.value_applied.connect (() => {
                this.changed ();
            });

            this.launch_option_handlers.add (tile);
            if (id != "" && presentation_registry != null)
                presentation_registry.register (id, tile, tile, presentation_movable);

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
