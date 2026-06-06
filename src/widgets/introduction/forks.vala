namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Forks : Base {
        public Forks () {
            base (
                  _("Custom Forks & Flavors"),
                  _("Community versions like Proton-GE provide cutting-edge fixes, video codecs, and game-specific tweaks before they hit the official releases."),
                  "%s/fork.svg".printf (Config.RESOURCE_BASE)
            );
        }
    }
}