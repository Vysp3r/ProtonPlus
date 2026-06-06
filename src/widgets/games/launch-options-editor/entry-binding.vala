namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    class EntryBinding : BaseBinding, ILaunchOption {
        public unowned LaunchOptionEntryField entry_field { get; set; }
        public unowned Gtk.Switch toggle { get; set; }

        public EntryBinding (LaunchOptionEntryField entry_field, Gtk.Switch toggle) {
            base (true, LaunchLineType.ADDITIONAL);
            this.entry_field = entry_field;
            this.toggle = toggle;
        }

        public void parse_tokens (string[] tokens_pool, bool[] consumed) {
            if (tokens_pool.length != consumed.length)return;

            var unconsumed_tokens = new Gee.LinkedList<string> ();

            for (var i = 0; i < tokens_pool.length; i++) {
                if (!consumed[i] && tokens_pool[i] != "%command%") {
                    unconsumed_tokens.add (tokens_pool[i]);
                    consumed[i] = true;
                }
            }

            if (unconsumed_tokens.size > 0) {
                string custom_args = string.joinv (" ", unconsumed_tokens.to_array ());

                this.entry_field.set_text (custom_args);
                this.toggle.set_active (true);
            }

            foreach (var child in this._children) {
                child.parse_tokens (tokens_pool, consumed);
            }
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (!this.toggle.get_active ())return;

            string text = this.entry_field.get_text ().strip ();
            if (text == "")return;

            string[] custom_tokens = text.split (" ");
            foreach (var token in custom_tokens) {
                if (token.strip () != "") {
                    segments.add (token);
                }
            }

            foreach (var child in this._children) {
                if (child.is_active ()) {
                    child.append_command_segments (segments);
                }
            }
        }

        public void clear () {
            this.toggle.set_active (false);
            this.entry_field.set_text ("");
            foreach (var child in this._children) {
                child.clear ();
            }
        }

        public bool is_active () {
            return this.toggle.get_active () && this.entry_field.get_text ().strip () != "";
        }

        public Gee.LinkedList<string> get_env_tokens () {
            var env_list = new Gee.LinkedList<string> ();
            if (!this.toggle.get_active ())return env_list;
            string text = this.entry_field.get_text ().strip ();

            if (text == "")return env_list;

            string[] custom_tokens = text.split (" ");
            foreach (var token in custom_tokens) {
                var cleaned_token = token.strip ();
                if (cleaned_token != "" && cleaned_token.contains ("=")) {
                    env_list.add (cleaned_token);
                }
            }
            return env_list;
        }

        public Gee.LinkedList<string> get_argument_tokens () {
            var arg_list = new Gee.LinkedList<string> ();
            if (!this.toggle.get_active ())return arg_list;
            string text = this.entry_field.get_text ().strip ();

            if (text == "")return arg_list;

            string[] custom_tokens = text.split (" ");
            foreach (var token in custom_tokens) {
                var cleaned_token = token.strip ();
                if (cleaned_token != "" && !cleaned_token.contains ("=")) {
                    arg_list.add (cleaned_token);
                }
            }
            return arg_list;
        }
    }
}