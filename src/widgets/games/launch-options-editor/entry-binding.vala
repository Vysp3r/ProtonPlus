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
            if (tokens_pool.length != consumed.length)
                return;

            string custom_args = "";

            for (var i = 0; i < tokens_pool.length; i++) {
                if (!consumed[i] && tokens_pool[i] != "%command%") {
                    if (custom_args != "")
                        custom_args += " ";

                    custom_args += tokens_pool[i];
                    consumed[i] = true;
                }
            }

            if (custom_args != "") {
                this.entry_field.set_text (custom_args);
                this.toggle.set_active (true);
            }

            foreach (var child in this._children) {
                child.parse_tokens (tokens_pool, consumed);
            }
        }

        public void append_command_segments (Gee.LinkedList<string> segments) {
            if (!this.toggle.get_active ())
                return;

            string text = this.entry_field.get_text ().strip ();
            if (text == "")
                return;

            foreach (var token in new LaunchOptionShellTokenizer ().tokenize (text))
                segments.add (token.raw);

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

        public void set_loaded_tokens (Gee.LinkedList<string> tokens) {
            if (tokens.size == 0)
                return;

            this.entry_field.set_text (string.joinv (" ", tokens.to_array ()));
            this.toggle.set_active (true);
        }
    }
}
