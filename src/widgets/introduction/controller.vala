namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Controller : Base {
        public Controller () {
            base (
                _("Controller support"),
                _("Navigate with the D-pad or left stick, and scroll with the right stick. Choose the Confirm face button, use contextual Back, switch sections or pages with the shoulders, and open menus or launchers with their controller buttons."), // vala-lint=line-length
                "gamepad-symbolic"
            );
        }
    }
}
