namespace ProtonPlus.Widgets.Tools {
    public class GameRow : Adw.ActionRow {
        Gtk.CheckButton select_check_button;
        public Models.Game game { get; set; }

        public bool selected { get; set; }

        public GameRow (Models.Game game) {
            this.game = game;
            title = game.name;
            tooltip_text = game.name;

            select_check_button = new Gtk.CheckButton ();
            select_check_button.set_tooltip_text (
                _("Select %s").printf (game.name)
            );
            select_check_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Select %s").printf (game.name),
                -1
            );
            select_check_button.bind_property ("active", this, "selected", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);

            add_prefix (select_check_button);
            set_activatable_widget (select_check_button);
            set_selectable (false);
        }
    }
}
