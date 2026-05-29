namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;

    class LaunchOptionTile : ActionRow {
        public Gtk.Switch toggle { get; private set; }

        public LaunchOptionTile (string title, string subtitle) {
            Object (title: title, subtitle: subtitle);
            subtitle_lines = 0;

            toggle = new Gtk.Switch ();
            toggle.set_valign (Gtk.Align.CENTER);
            add_suffix (toggle);
            activatable_widget = toggle;
        }
    }
}