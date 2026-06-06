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

        public Scopebuddy (owned SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            base (standard_control_changed, launch_option_handlers);
            bindings = new List<LaunchOptionBinding> ();
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

            fullscreen_tile = new LaunchOptionTile (_("Fullscreen"), _("Runs the game in a fullscreen session."));
            fullscreen_tile.toggle.notify["active"].connect (() => {
                standard_control_changed ();
            });

            auto_hdr_tile = new LaunchOptionTile (_("Auto HDR"), _("Outputs HDR colors if your display supports it."));
            auto_hdr_tile.toggle.notify["active"].connect (() => {
                standard_control_changed ();
            });

            auto_vrr_tile = new LaunchOptionTile (_("VRR"), _("Matches your display's refresh rate to the game's FPS."));
            auto_vrr_tile.toggle.notify["active"].connect (() => {
                standard_control_changed ();
            });

            framerate_tile = new LaunchOptionSpinTile (_("Frame limit"), _("Caps the frame rate inside ScopeBuddy."), _("FPS"), 30, 360, 60, "-r ");
            framerate_tile.toggle.notify["active"].connect (() => {
                standard_control_changed ();
            });
            framerate_tile.value_applied.connect (() => {
                standard_control_changed ();
            });

            bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_HDR=1" }, auto_hdr_tile.toggle));
            bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_VRR=1" }, auto_vrr_tile.toggle));

            resolution_field = new LaunchOptionResolutionField (_("Resolution"), _("Sets the ScopeBuddy output resolution."), true, true);
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

            args_field = new LaunchOptionEntryField (_("Additional ScopeBuddy arguments"), _("Keeps extra ScopeBuddy flags such as preferred output selection."), _("Add ScopeBuddy arguments"));
            args_field.value_applied.connect (() => {
                standard_control_changed ();
            });

            group.add (fullscreen_tile);
            group.add (auto_hdr_tile);
            group.add (auto_vrr_tile);
            group.add (framerate_tile);
            group.add (resolution_field);
            group.add (args_field);

            return group;
        }
    }
}