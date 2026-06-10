namespace ProtonPlus.Widgets.Tools {
    public class GameRow : Gtk.ListBoxRow {
        Gtk.CheckButton select_check_button;
        Gtk.Label title_label;
        Gtk.Box content_box;
        public Models.Game game { get; set; }

        public bool selected { get; set; }

        public GameRow (Models.Game game) {
            this.game = game;

            select_check_button = new Gtk.CheckButton ();
            select_check_button.set_size_request (30, 0);
            select_check_button.bind_property ("active", this, "selected", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);

            title_label = new Gtk.Label (game.name);
            title_label.set_tooltip_text (title_label.get_label ());
            title_label.set_halign (Gtk.Align.START);
            title_label.set_hexpand (true);
            title_label.set_ellipsize (Pango.EllipsizeMode.END);

            content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            content_box.set_hexpand (true);
            content_box.set_margin_start (12);
            content_box.set_margin_end (12);
            content_box.set_margin_top (12);
            content_box.set_margin_bottom (12);
            content_box.set_valign (Gtk.Align.CENTER);
            content_box.append (select_check_button);
            content_box.append (title_label);

            set_child (content_box);
            set_selectable (false);
        }
    }
}
