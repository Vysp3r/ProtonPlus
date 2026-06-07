namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public delegate void SimpleCallback ();

    public abstract class Base : Object, ILaunchOption {
        protected unowned SimpleCallback standard_control_changed;
        protected unowned LaunchOptionsList launch_option_handlers;
        public bool is_advanced { get; set; }
        public LaunchLineType line_type { get; set; }
        protected Gee.List<ILaunchOption> _children;

        public bool active { get; set; }

        protected Base (SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            this.standard_control_changed = standard_control_changed;
            this.launch_option_handlers = launch_option_handlers;
            this.line_type = LaunchLineType.WRAPPER;
            this._children = new Gee.ArrayList<ILaunchOption> ();
            this.is_advanced = false;
            this.launch_option_handlers.add (this);
            this.active = false;
        }

        internal LaunchOptionBinding create_bind (string[] tokens,
                                                  Gtk.Switch toggle,
                                                  bool is_advanced,
                                                  ProtonPlus.Widgets.Games.LaunchOptionsEditor.LaunchLineType line_type) {
            return new LaunchOptionBinding (tokens, toggle, is_advanced, line_type);
        }

        internal LaunchOptionTile create_tile (string title, string subtitle, string[] tokens, bool is_advanced = false, LaunchLineType type = LaunchLineType.WRAPPER_ARGUMENT) {
            var tile = new LaunchOptionTile (title, subtitle, tokens, is_advanced, type);
            tile.toggle.notify["active"].connect (() => {
                this.standard_control_changed ();
            });

            this.add_child (tile);

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

            this.add_child (tile);

            return tile;
        }

        internal int get_wrapper_end_index (string[] tokens, int wrapper_index, bool[] consumed) {
            var command_index = get_token_index (tokens, "%command%");
            if (command_index > wrapper_index && command_index > 0 && tokens[command_index - 1] == "--") {
                consumed[command_index - 1] = true;
                return command_index - 1;
            }

            return tokens.length;
        }

        internal int get_first_present_index (string[] tokens, string[] candidates) {
            for (var index = 0; index < tokens.length; index++) {
                foreach (var candidate in candidates) {
                    if (tokens[index] == candidate)
                        return index;
                }
            }

            return -1;
        }

        internal int get_token_index (string[] tokens, string token) {
            for (var index = 0; index < tokens.length; index++) {
                if (tokens[index] == token)
                    return index;
            }

            return -1;
        }

        internal void append_token (StringBuilder output, string token) {
            if (output.len > 0)
                output.append (" ");

            output.append (token);
        }

        internal int get_unconsumed_token_index (string[] tokens, string token, bool[] consumed) {
            for (var index = 0; index < tokens.length; index++) {
                if (!consumed[index] && tokens[index] == token)
                    return index;
            }

            return -1;
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