namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public class Scopebuddy : Base {

        LaunchOptionTile fullscreen_tile { get; set; }
        LaunchOptionTile auto_hdr_tile { get; set; }
        LaunchOptionTile auto_vrr_tile { get; set; }
        LaunchOptionSpinTile framerate_tile { get; set; }
        LaunchOptionResolutionField resolution_field { get; set; }
        LaunchOptionEntryField args_field { get; set; }
        List<LaunchOptionBinding> bindings;
        Gtk.Widget cached_page;

        public Scopebuddy (LaunchOptionsList launch_option_handlers) {
            base (launch_option_handlers);
            bindings = new List<LaunchOptionBinding> ();
            cached_page = null;
        }

        public void selection_change () {
            fullscreen_tile.toggle.set_active (false);
            framerate_tile.toggle.set_active (false);
            framerate_tile.set_value (60);
            resolution_field.reset ();
            args_field.set_text ("");
            foreach (var binding in bindings) {
                binding.toggle.set_active (false);
            }
        }

        public Gtk.Widget create_page () {
            var group = new Adw.PreferencesGroup ();
            if (cached_page != null) {
                return cached_page;
            }

            fullscreen_tile = create_tile (_("Fullscreen"), _("Runs the game in a fullscreen session."), { "-f" }, true);
            fullscreen_tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            auto_hdr_tile = create_tile (_("Auto HDR"), _("Outputs HDR colors if your display supports it."), { "SCB_AUTO_HDR=1" }, true);
            auto_hdr_tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            auto_vrr_tile = create_tile (_("VRR"), _("Matches your display's refresh rate to the game's FPS."), { "SCB_AUTO_VRR=1" }, true);
            auto_vrr_tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            framerate_tile = new LaunchOptionSpinTile (_("Frame limit"), _("Caps the frame rate inside ScopeBuddy."), _("FPS"), 30, 360, 60, "-r ");
            framerate_tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });
            framerate_tile.value_applied.connect (() => {
                this.changed ();
            });

            bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_HDR=1" }, auto_hdr_tile.toggle));
            bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_VRR=1" }, auto_vrr_tile.toggle));

            resolution_field = new LaunchOptionResolutionField (_("Resolution"), _("Sets the ScopeBuddy output resolution."), true, true);
            resolution_field.toggle.notify["active"].connect (() => {
                this.changed ();
            });
            resolution_field.dropdown.notify["selected"].connect (() => {
                this.changed ();
            });
            resolution_field.value_applied.connect (() => {
                this.changed ();
            });
            launch_option_handlers.add (resolution_field);

            args_field = new LaunchOptionEntryField (_("Additional ScopeBuddy arguments"), _("Keeps extra ScopeBuddy flags such as preferred output selection."), _("Add ScopeBuddy arguments"));
            args_field.value_applied.connect (() => {
                this.changed ();
            });

            group.add (fullscreen_tile);
            group.add (auto_hdr_tile);
            group.add (auto_vrr_tile);
            group.add (framerate_tile);
            group.add (resolution_field);
            group.add (args_field);


            this.add_child (fullscreen_tile);
            this.add_child (auto_hdr_tile);
            this.add_child (auto_vrr_tile);
            this.add_child (framerate_tile);
            this.add_child (resolution_field);
            // this.add_child (args_field);

            cached_page = group;
            return group;
        }

        public override void clear () {
            foreach (var child in this._children) {
                child.clear ();
            }

            args_field.set_text ("");
        }

        public override void parse_tokens (string[] tokens, bool[] consumed) {
            var wrapper_index = get_first_present_index (tokens, { "scopebuddy", "scb" });
            if (wrapper_index < 0) {
                this.active = false;
                return;
            }

            this.active = true;
            consumed[wrapper_index] = true;

            var end_index = get_wrapper_end_index (tokens, wrapper_index, consumed);
            var extra_args = new StringBuilder ();

            for (var index = wrapper_index + 1; index < end_index; index++) {
                if (consumed[index])continue;

                if (tokens[index] == "-f") {
                    fullscreen_tile.toggle.set_active (true);
                    consumed[index] = true;
                    continue;
                }

                if (tokens[index] == "-r" && index + 1 < end_index) {
                    int framerate;
                    if (int.try_parse (tokens[index + 1], out framerate)) {
                        framerate_tile.toggle.set_active (true);
                        framerate_tile.set_value (framerate);
                        consumed[index] = true;
                        consumed[index + 1] = true;
                        index++;
                        continue;
                    }
                }

                append_token (extra_args, tokens[index]);
                consumed[index] = true;
            }

            args_field.set_text (extra_args.str);
        }

        public override void append_command_segments (Gee.LinkedList<string> segments) {
            if (!this.is_active ())return;
            print ("Appending scopebuddy segments.\n");
            segments.add ("scopebuddy");

            foreach (var child in this._children) {
                if (child.is_active ()) {
                    child.append_command_segments (segments);
                }
            }
            segments.add ("--");
        }
    }
}
