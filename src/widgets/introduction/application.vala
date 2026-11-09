namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Application : Base {
        public Application () {
            base (
                  _("Welcome to ProtonPlus"),
                  _("Install and manage compatibility tools for your Linux game launchers"),
                  "com.vysp3r.ProtonPlus"
            );
        }
    }
}
