namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Proton : Base {
        public Proton () {
            base (
                  _("What is Proton?"),
                  _("Developed by Valve, Proton is a tool based on Wine specifically optimized for gaming, ensuring high performance and Steam Play integration."),
                  "%s/icons/scalable/actions/proton-symbolic.svg".printf (Config.RESOURCE_BASE)
            );
        }
    }
}