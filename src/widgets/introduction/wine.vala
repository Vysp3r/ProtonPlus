namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Wine : Base {
        public Wine () {
            base (
                  _("What is Wine?"),
                  _("Wine is a compatibility layer capable of running Windows applications on Linux systems by translating Windows API calls on the fly."),
                  "preferences-desktop-gaming-symbolic"
            );
        }
    }
}