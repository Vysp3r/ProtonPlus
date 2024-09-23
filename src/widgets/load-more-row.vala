namespace ProtonPlus.Widgets {
    public class LoadMoreRow : Adw.ActionRow {
        Gtk.Button btn_load { get; set; }
        Gtk.Box suffix_content { get; set; }

        construct {
            btn_load = new Gtk.Button.from_icon_name ("dots-symbolic");
            btn_load.set_tooltip_text (_("Load more"));
            btn_load.add_css_class ("flat");
            btn_load.clicked.connect (() => activated ());

            suffix_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            suffix_content.set_margin_end (10);
            suffix_content.set_valign (Gtk.Align.CENTER);
            suffix_content.append (btn_load);

            set_title (_("Load more"));
            add_suffix (suffix_content);
        }
    }
}