namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class WrapperGroup : BaseOptionsGroup {

        public Gtk.Stack stack { get; set; }
        Gtk.StackSwitcher switcher { get; set; }
        Wrappers.Gamescope gamescope { get; set; }
        Wrappers.Scopebuddy scopebuddy { get; set; }
        Wrappers.None none { get; set; }

        bool refreshing_controls;

        public WrapperGroup (owned SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            base (standard_control_changed, launch_option_handlers);
            refreshing_controls = true;

            this.title = _("Launch tools");
            this.description = _("Choose one to configure FPS caps, resolution, and other display options.");

            none = new Wrappers.None (standard_control_changed, launch_option_handlers);
            gamescope = new Wrappers.Gamescope (standard_control_changed, launch_option_handlers);
            scopebuddy = new Wrappers.Scopebuddy (standard_control_changed, launch_option_handlers);

            var gamescope_page = gamescope.create_page ();
            var scopebuddy_page = scopebuddy.create_page ();
            var none_page = none.create_page ();

            stack = new Gtk.Stack ();
            stack.set_hhomogeneous (false);
            stack.set_vhomogeneous (false);
            stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
            stack.notify["visible-child-name"].connect (() => {
                selection_changed ();
            });

            stack.add_titled (none_page, "none", _("None"));

            if (Globals.GAMESCOPE_INSTALLED)
                stack.add_titled (gamescope_page, "gamescope", _("Gamescope"));
            else
                stack.add_named (gamescope_page, "gamescope");

            if (Globals.SCOPEBUDDY_INSTALLED)
                stack.add_titled (scopebuddy_page, "scopebuddy", _("ScopeBuddy"));
            else
                stack.add_named (scopebuddy_page, "scopebuddy");

            switcher = new Gtk.StackSwitcher ();
            switcher.set_stack (stack);
            switcher.set_halign (Gtk.Align.START);

            if (!Globals.GAMESCOPE_INSTALLED && !Globals.SCOPEBUDDY_INSTALLED)
                switcher.visible = false;

            this.set_header_suffix (switcher);
            this.add (stack);

            refreshing_controls = false;
        }

        void selection_changed () {
            if (refreshing_controls)
                return;

            refreshing_controls = true;

            var current_wrapper = stack.get_visible_child_name ();

            if (current_wrapper != "none") {
                scopebuddy.active = false;
                gamescope.active = false;
                none.selection_change ();
            }

            if (current_wrapper != "gamescope") {
                gamescope.active = true;
                scopebuddy.active = false;
                gamescope.selection_change ();
            }

            if (current_wrapper != "scopebuddy") {
                scopebuddy.active = false;
                gamescope.active = true;
                scopebuddy.selection_change ();
            }

            refreshing_controls = false;
        }
    }
}