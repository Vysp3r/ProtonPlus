namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    class LaunchOptionTile : ActionRow, ILaunchOption {
        public string[] tokens { get; set; }
        public Gtk.Switch toggle { get; private set; }
        public LaunchLineType line_type { get; set; default = LaunchLineType.ENVIRONMENT; }
        protected Gee.List<ILaunchOption> _children;
        public bool is_advanced { get; set; default = false; }

        public LaunchOptionTile (string title, string subtitle, string[] tokens, bool is_advanced = false, LaunchLineType line_type = LaunchLineType.ENVIRONMENT) {
            Object ();
            this.title = title;
            this.subtitle = subtitle;
            this.subtitle_lines = 0;
            this.tokens = tokens;

            toggle = new Gtk.Switch ();
            toggle.set_valign (Gtk.Align.CENTER);
            add_suffix (toggle);
            activatable_widget = toggle;
            this.is_advanced = is_advanced;
            this.line_type = line_type;
            this._children = new Gee.ArrayList<ILaunchOption> ();
        }

        public void add_child (ILaunchOption child) {
            this._children.add (child);
        }

        public void parse_tokens (string[] tokens_pool, bool[] consumed) {
            if (tokens_pool.length != consumed.length) {
                return;
            }

            var token_indexes = new Gee.LinkedList<int> ();
            var all_tokens_present = true;

            foreach (var token in this.tokens) {
                var token_index = get_unconsumed_token_index (tokens_pool, token, consumed);
                if (token_index < 0) {
                    all_tokens_present = false;
                    break;
                }
                token_indexes.add (token_index);
            }

            if (all_tokens_present && this.toggle != null) {
                this.toggle.set_active (true);
                foreach (var token_index in token_indexes) {
                    consumed[token_index] = true;
                }
            }

            foreach (var child in this._children) {
                child.parse_tokens (tokens_pool, consumed);
            }
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (!this.toggle.get_active ()) {
                return;
            }

            foreach (var token in this.tokens) {
                segments.add (token);
            }

            foreach (var child in this._children) {
                if (child.is_active ()) {
                    child.append_command_segments (segments);
                }
            }
        }

        public void clear () {
            this.toggle.set_active (false);
            foreach (var child in this._children) {
                child.clear ();
            }
        }

        public bool is_active () {
            return this.toggle.get_active ();
        }

        private int get_unconsumed_token_index (string[] tokens_pool, string token, bool[] consumed) {
            for (var index = 0; index < tokens_pool.length; index++) {
                if (!consumed[index] && tokens_pool[index] == token) {
                    return index;
                }
            }
            return -1;
        }
    }
}