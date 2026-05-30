namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
    class LaunchOptionBinding : Object, ILaunchOption {
        public string[] tokens { get; set; }
        public Gtk.Switch toggle { get; set; }

        public bool is_advanced { get; set; default = false; }

        public LaunchOptionBinding (string[] tokens, Gtk.Switch toggle, bool is_advanced = false) {
            this.tokens = tokens;
            this.toggle = toggle;
            this.is_advanced = is_advanced;
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

            if (all_tokens_present) {
                this.toggle.set_active (true);
                foreach (var token_index in token_indexes) {
                    consumed[token_index] = true;
                }
            }
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (!this.toggle.get_active ()) {
                return;
            }

            foreach (var token in this.tokens) {
                segments.add (token);
            }
        }

        public void clear () {
            this.toggle.set_active (false);
        }

        private int get_unconsumed_token_index (string[] tokens_pool, string token, bool[] consumed) {
            for (var index = 0; index < tokens_pool.length; index++) {
                if (!consumed[index] && tokens_pool[index] == token) {
                    return index;
                }
            }
            return -1;
        }

        public bool is_active () {
            return this.toggle.get_active ();
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

            if (all_tokens_present) {
                this.toggle.set_active (true);
                foreach (var token_index in token_indexes) {
                    consumed[token_index] = true;
                }
            }
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (!this.toggle.get_active ()) {
                return;
            }

            foreach (var token in this.tokens) {
                segments.add (token);
            }
        }

        public void clear () {
            this.toggle.set_active (false);
        }

        private int get_unconsumed_token_index (string[] tokens_pool, string token, bool[] consumed) {
            for (var index = 0; index < tokens_pool.length; index++) {
                if (!consumed[index] && tokens_pool[index] == token) {
                    return index;
                }
            }
            return -1;
        }

        public bool is_active () {
            return this.toggle.get_active ();
        }
    }
}