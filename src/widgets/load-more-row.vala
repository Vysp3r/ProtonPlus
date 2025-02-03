namespace ProtonPlus.Widgets {
    public class LoadMoreRow : Adw.ActionRow {
        Gtk.Button load_button { get; set; }
        Gtk.Box suffix_box { get; set; }

        construct {
            load_button = new Gtk.Button.from_icon_name ("dots-symbolic");
            load_button.set_tooltip_text (_("Load more"));
            load_button.add_css_class ("flat");
            load_button.clicked.connect (() => activated ());

            suffix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            suffix_box.set_margin_end (10);
            suffix_box.set_valign (Gtk.Align.CENTER);
            suffix_box.append (load_button);

            set_title (_("Load more"));
            add_suffix (suffix_box);
        }
    }
}