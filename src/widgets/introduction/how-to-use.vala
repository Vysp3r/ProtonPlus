namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class HowToUse : Base {
        public HowToUse () {
            base (
                _("Install and Select a Tool"),
                _("Open a tool in the Tools tab, choose a release, and select Install. Then select the installed tool for your game in ProtonPlus’s Games tab where supported, or in your launcher’s settings. Follow any Steam restart prompt to finish applying changes."), // vala-lint=line-length
                "%s/rocket.svg".printf (Config.RESOURCE_BASE)
            );
        }
    }
}
