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

            gamescope.notify["active"].connect (() => {
                if (gamescope.active && !refreshing_controls) {
                    refreshing_controls = true;
                    stack.set_visible_child_name ("gamescope");
                    refreshing_controls = false;
                }
            });

            scopebuddy.notify["active"].connect (() => {
                if (scopebuddy.active && !refreshing_controls) {
                    refreshing_controls = true;
                    stack.set_visible_child_name ("scopebuddy");
                    refreshing_controls = false;
                }
            });

            refreshing_controls = true;
            stack.set_visible_child_name ("none");
            refreshing_controls = false;
            selection_changed ();
        }

        void selection_changed () {
            if (refreshing_controls)
                return;

            refreshing_controls = true;

            var current_wrapper = stack.get_visible_child_name ();

            if (current_wrapper == "none") {
                none.active = true;
                gamescope.active = false;
                scopebuddy.active = false;
                gamescope.selection_change ();
                scopebuddy.selection_change ();
            } else if (current_wrapper == "gamescope") {
                gamescope.active = true;
                none.active = false;
                scopebuddy.active = false;
                none.selection_change ();
                scopebuddy.selection_change ();
            } else if (current_wrapper == "scopebuddy") {
                scopebuddy.active = true;
                none.active = false;
                gamescope.active = false;
                none.selection_change ();
                gamescope.selection_change ();
            }

            refreshing_controls = false;
            this.standard_control_changed ();
        }
    }
}