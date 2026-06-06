namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Application : Base {
        public Application () {
            base (
                  _("Welcome to ProtonPlus"),
                  _("ProtonPlus helps you easily manage, install, and update compatibility layers for running Windows games on Linux."),
                  "org.gnome.Software-symbolic" // Zde doplňte vhodnou ikonu
            );
        }
    }
}