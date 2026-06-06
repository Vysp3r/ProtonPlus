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

            fullscreen_tile = create_tile (_("Fullscreen"), _("Runs the game in a fullscreen session."), { "-f" });

            hdr_tile = new LaunchOptionTile (_("HDR"), _("Outputs HDR colors if your display supports it."));
            hdr_tile.toggle.notify["active"].connect (() => {
                standard_control_changed ();
            });

            vrr_tile = new LaunchOptionTile (_("VRR"), _("Matches your display's refresh rate to the game's FPS."));
            vrr_tile.toggle.notify["active"].connect (() => {
                standard_control_changed ();
            });

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

            // launch_option_handlers.add (resolution_field);
            // launch_option_handlers.add (resolution_field);
            launch_option_handlers.add (resolution_field);

            group.add (fullscreen_tile);
            group.add (hdr_tile);
            group.add (vrr_tile);
            group.add (framerate_tile);
            group.add (resolution_field);

            args_field = new LaunchOptionEntryField (_("Additional Gamescope arguments"), _("Keeps extra Gamescope flags such as output or resolution tweaks."), _("Add Gamescope arguments"));
            args_field.value_applied.connect (() => {
                standard_control_changed ();
            });

            group.add (args_field);

            return group;
        }
    }
}