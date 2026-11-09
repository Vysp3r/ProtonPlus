namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Proton : Base {
        public Proton () {
            base (
                _("What is Proton?"),
                _("Proton combines Wine with gaming components for Steam Play. For Steam games, choose a Proton build. You can keep several versions installed for games with different needs."), // vala-lint=line-length
                "%s/icons/scalable/actions/proton-symbolic.svg".printf (Config.RESOURCE_BASE)
            );
        }
    }
}
