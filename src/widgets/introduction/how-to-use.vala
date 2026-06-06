namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class HowToUse : Base {
        public HowToUse () {
            base (
                  _("How to Use"),
                  _("Simply browse the available compatibility tools, click download, and ProtonPlus will automatically configure them for your launchers like Steam, Heroic, or Lutris."),
                  "help-browser-symbolic"
            );
        }
    }
}