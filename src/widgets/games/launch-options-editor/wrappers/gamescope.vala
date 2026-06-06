namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public class Gamescope : Base {

        LaunchOptionTile fullscreen_tile { get; set; }
        LaunchOptionTile hdr_tile { get; set; }
        LaunchOptionTile vrr_tile { get; set; }
        LaunchOptionSpinTile framerate_tile { get; set; }
        LaunchOptionResolutionField resolution_field { get; set; }
        LaunchOptionEntryField args_field { get; set; }

        public Gamescope (owned SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            base (standard_control_changed, launch_option_handlers);
        }

        public void selection_change () {
            fullscreen_tile.toggle.set_active (false);
            hdr_tile.toggle.set_active (false);
            vrr_tile.toggle.set_active (false);
            framerate_tile.toggle.set_active (false);
            framerate_tile.set_value (60);
            resolution_field.reset ();
            args_field.set_text ("");
        }

        public Gtk.Widget create_page () {
            var group = new Adw.PreferencesGroup ();

            fullscreen_tile = create_tile (_("Fullscreen"), _("Runs the game in a fullscreen session."), { "-f" }, true);

            hdr_tile = create_tile (_("HDR"), _("Outputs HDR colors if your display supports it."), { "--hdr-enabled" }, true);

            vrr_tile = create_tile (_("VRR"), _("Matches your display's refresh rate to the game's FPS."), { "--adaptive-sync" }, true);


            framerate_tile = new LaunchOptionSpinTile (_("Frame limit"), _("Caps the frame rate inside Gamescope."), _("FPS"), 30, 360, 60, "-r ");
            framerate_tile.toggle.notify["active"].connect (() => {
                standard_control_changed ();
            });
            framerate_tile.value_applied.connect (() => {
                standard_control_changed ();
            });

            resolution_field = new LaunchOptionResolutionField (_("Resolution"), _("Sets the Gamescope output resolution."), false, false);
            resolution_field.toggle.notify["active"].connect (() => {
                standard_control_changed ();
            });
            resolution_field.dropdown.notify["selected"].connect (() => {
                standard_control_changed ();
            });
            resolution_field.value_applied.connect (() => {
                standard_control_changed ();
            });

            launch_option_handlers.add (resolution_field);

            group.add (fullscreen_tile);
            group.add (hdr_tile);
            group.add (vrr_tile);
            group.add (framerate_tile);
            group.add (resolution_field);

            this.add_child (framerate_tile);
            this.add_child (resolution_field);

            args_field = new LaunchOptionEntryField (_("Additional Gamescope arguments"), _("Keeps extra Gamescope flags such as output or resolution tweaks."), _("Add Gamescope arguments"));
            args_field.value_applied.connect (() => {
                standard_control_changed ();
            });

            group.add (args_field);

            return group;
        }

        public override void clear () {
            foreach (var child in this._children) {
                child.clear ();
            }
            args_field.set_text ("");
        }

        public override void parse_tokens (string[] tokens, bool[] consumed) {
            var wrapper_index = get_first_present_index (tokens, { "gamescope" });
            if (wrapper_index < 0)
                return;

            consumed[wrapper_index] = true;

            var end_index = get_wrapper_end_index (tokens, wrapper_index, consumed);
            var extra_args = new StringBuilder ();

            for (var index = wrapper_index + 1; index < end_index; index++) {
                var token = tokens[index];

                if (consumed[index])continue;

                if (token == "-f") {
                    fullscreen_tile.toggle.set_active (true);
                    consumed[index] = true;
                    continue;
                }

                if (token == "--hdr-enabled") {
                    hdr_tile.toggle.set_active (true);
                    consumed[index] = true;
                    continue;
                }

                if (token == "--adaptive-sync") {
                    vrr_tile.toggle.set_active (true);
                    consumed[index] = true;
                    continue;
                }

                if (token == "-r" && index + 1 < end_index) {
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

                append_token (extra_args, token);
                consumed[index] = true;
            }

            args_field.set_text (extra_args.str);

            foreach (var child in this._children) {
                child.parse_tokens (tokens, consumed);
            }
        }

        public override void append_command_segments (Gee.LinkedList<string> segments) {
            if (!this.is_active ())return;
            print ("Appending Gamescope segments.\n");
            segments.add ("gamescope");

            foreach (var child in this._children) {
                if (child.is_active ()) {
                    child.append_command_segments (segments);
                }
            }
        }
    }
}