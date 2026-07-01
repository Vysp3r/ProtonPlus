namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class BaseOptionsGroup : PreferencesGroup {
        protected unowned LaunchOptionsList launch_option_handlers;
        public signal void changed ();
        public signal void advanced_changed ();

        internal bool is_advanced_group { get; set; default = false; }

        public BaseOptionsGroup (LaunchOptionsList launch_option_handlers, bool is_advanced_group = false) {
            this.launch_option_handlers = launch_option_handlers;
            this.is_advanced_group = is_advanced_group;
        }

        internal LaunchOptionTile create_game_argument_tile (string title, string subtitle, string[] tokens, bool is_advanced = false) {
            return create_tile (title, subtitle, tokens, is_advanced, LaunchLineType.ARGUMENT);
        }

        internal LaunchOptionTile create_tile (string title, string subtitle, string[] tokens, bool is_advanced = false, LaunchLineType type = LaunchLineType.ENVIRONMENT) {
            var tile = new LaunchOptionTile (title, subtitle, tokens, is_advanced, type);
            tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            this.launch_option_handlers.add (tile);

            return tile;
        }

        internal LaunchOptionSpinTile create_spin_tile (string title, string subtitle, string value_label, double lower, double upper, int default_value, string env_prefix, bool is_advanced = false, LaunchLineType type = LaunchLineType.ENVIRONMENT) {
            var tile = new LaunchOptionSpinTile (title, subtitle, value_label, lower, upper, default_value, env_prefix);
            tile.line_type = type;
            tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            tile.value_applied.connect (() => {
                this.changed ();
            });

            this.launch_option_handlers.add (tile);

            return tile;
        }

        internal bool has_active_options () {
            for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
                var option = child as ILaunchOption;
                if (option != null && option.is_active ())
                    return true;
            }

            return false;
        }

        public virtual bool has_advanced_active () {
            return this.is_advanced_group;
        }
    }
}
