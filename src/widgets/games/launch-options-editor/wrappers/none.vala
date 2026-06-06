namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public class None : Base {
        LaunchOptionTile hdr_tile { get; set; }

        public None (owned SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            base (standard_control_changed, launch_option_handlers);
        }

        public Gtk.Widget create_page () {
            var group = new Adw.PreferencesGroup ();

            hdr_tile = create_tile (_("HDR"), _("Outputs HDR colors if your display supports it."), { "PROTON_ENABLE_HDR=1" }, false, LaunchLineType.ENVIRONMENT);

            group.add (hdr_tile);
            this.add_child (hdr_tile);

            return group;
        }

        public void selection_change () {
            hdr_tile.toggle.set_active (false);
        }

        public override void clear () {
            foreach (var child in this._children) {
                child.clear ();
            }
        }

        public override void parse_tokens (string[] tokens, bool[] consumed) {
            var hdr_index = get_unconsumed_token_index (tokens, "PROTON_ENABLE_HDR=1", consumed);
            if (hdr_index < 0) {
                hdr_tile.toggle.set_active (false);
                return;
            }

            hdr_tile.toggle.set_active (true);
            consumed[hdr_index] = true;

            foreach (var child in this._children) {
                child.parse_tokens (tokens, consumed);
            }
        }

        public override void append_command_segments (Gee.LinkedList<string> segments) {
            if (hdr_tile.toggle.get_active ())
                segments.add ("PROTON_ENABLE_HDR=1");
        }
    }
}