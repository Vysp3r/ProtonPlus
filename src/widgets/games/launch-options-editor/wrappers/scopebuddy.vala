namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public class Scopebuddy : Base {

        LaunchOptionTile scopebuddy_fullscreen_tile { get; set; }
        LaunchOptionTile scopebuddy_auto_hdr_tile { get; set; }
        LaunchOptionTile scopebuddy_auto_vrr_tile { get; set; }
        LaunchOptionSpinTile scopebuddy_framerate_tile { get; set; }
        LaunchOptionResolutionField scopebuddy_resolution_field { get; set; }
        LaunchOptionEntryField scopebuddy_args_field { get; set; }
        List<LaunchOptionBinding> scopebuddy_bindings;

        public Scopebuddy (owned SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            base(standard_control_changed, launch_option_handlers);
            scopebuddy_bindings = new List<LaunchOptionBinding> ();
        }

        Gtk.Widget create_page () {
            var group = new Adw.PreferencesGroup ();

            scopebuddy_fullscreen_tile = new LaunchOptionTile (_ ("Fullscreen"), _ ("Runs the game in a fullscreen session."));
            scopebuddy_fullscreen_tile.toggle.notify["active"].connect (() => {
                standard_control_changed();
            });

            scopebuddy_auto_hdr_tile = new LaunchOptionTile (_ ("Auto HDR"), _ ("Outputs HDR colors if your display supports it."));
            scopebuddy_auto_hdr_tile.toggle.notify["active"].connect (() => {
                standard_control_changed();
            });

            scopebuddy_auto_vrr_tile = new LaunchOptionTile (_ ("VRR"), _ ("Matches your display's refresh rate to the game's FPS."));
            scopebuddy_auto_vrr_tile.toggle.notify["active"].connect (() => {
                standard_control_changed();
            });

            scopebuddy_framerate_tile = new LaunchOptionSpinTile (_ ("Frame limit"), _ ("Caps the frame rate inside ScopeBuddy."), _ ("FPS"), 30, 360, 60, "-r ");
            scopebuddy_framerate_tile.toggle.notify["active"].connect (() => {
                standard_control_changed();
            });
            scopebuddy_framerate_tile.value_applied.connect (() => {
                standard_control_changed();
            });

            scopebuddy_bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_HDR=1" }, scopebuddy_auto_hdr_tile.toggle));
            scopebuddy_bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_VRR=1" }, scopebuddy_auto_vrr_tile.toggle));

            scopebuddy_resolution_field = new LaunchOptionResolutionField (_ ("Resolution"), _ ("Sets the ScopeBuddy output resolution."), true, true);
            scopebuddy_resolution_field.toggle.notify["active"].connect (() => {
                standard_control_changed();
            });
            scopebuddy_resolution_field.dropdown.notify["selected"].connect (() => {
                standard_control_changed();
            });
            scopebuddy_resolution_field.value_applied.connect (() => {
                standard_control_changed();
            });
            launch_option_handlers.add (scopebuddy_resolution_field);

            scopebuddy_args_field = new LaunchOptionEntryField (_ ("Additional ScopeBuddy arguments"), _ ("Keeps extra ScopeBuddy flags such as preferred output selection."), _ ("Add ScopeBuddy arguments"));
            scopebuddy_args_field.value_applied.connect (() => {
                standard_control_changed();
            });

            group.add (scopebuddy_fullscreen_tile);
            group.add (scopebuddy_auto_hdr_tile);
            group.add (scopebuddy_auto_vrr_tile);
            group.add (scopebuddy_framerate_tile);
            group.add (scopebuddy_resolution_field);
            group.add (scopebuddy_args_field);

            return group;
        }
    }
}
