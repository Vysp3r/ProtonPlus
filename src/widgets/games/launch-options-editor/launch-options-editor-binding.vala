namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
    class LaunchOptionBinding : Object {
        public string[] tokens { get; set; }
        public Gtk.Switch toggle { get; set; }

        public LaunchOptionBinding (string[] tokens, Gtk.Switch toggle) {
            this.tokens = tokens;
            this.toggle = toggle;
        }
    }
}