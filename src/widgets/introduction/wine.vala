namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Wine : Base {
        public Wine () {
            base (
                  _("What is Wine?"),
                  _("Wine lets Windows applications run on Linux by translating Windows API calls. Launchers such as Lutris use Wine builds; choose a build that suits the game you want to play."),
                  "%s/winezgui.svg".printf (Config.RESOURCE_BASE)
            );
        }
    }
}
