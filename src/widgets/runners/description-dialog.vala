namespace ProtonPlus.Widgets {
    public class DescriptionDialog : Adw.Dialog {
        Models.Release release { get; set; }

        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.ButtonContent web_button_content { get; set; }
        Gtk.Button web_button { get; set; }
        Adw.HeaderBar header_bar { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        Gtk.Label description_label { get; set; }

        construct {
            set_title (_ ("More information"));
            set_content_width (750);
            set_content_height (450);

            window_title = new Adw.WindowTitle (_ ("More information"), "");

            web_button_content = new Adw.ButtonContent ();
            web_button_content.set_icon_name ("globe-symbolic");
            web_button_content.set_label (_ ("Open"));

            web_button = new Gtk.Button ();
            web_button.set_child (web_button_content);
            web_button.set_tooltip_text (_ ("Open in your web browser"));
            web_button.clicked.connect (web_button_clicked);

            header_bar = new Adw.HeaderBar ();
            header_bar.pack_start (web_button);
            header_bar.set_title_widget (window_title);

            description_label = new Gtk.Label (null);
            description_label.set_valign (Gtk.Align.START);
            description_label.set_halign (Gtk.Align.START);
            description_label.set_wrap (true);
            description_label.set_selectable (true);
            description_label.set_xalign (0);
            description_label.set_wrap_mode (Pango.WrapMode.WORD_CHAR);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (description_label);
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.add_css_class ("card");
            scrolled_window.add_css_class ("p-10");
            scrolled_window.set_overflow (Gtk.Overflow.HIDDEN);
            scrolled_window.set_margin_top (7);
            scrolled_window.set_margin_bottom (12);
            scrolled_window.set_margin_start (12);
            scrolled_window.set_margin_end (12);

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (scrolled_window);

            set_child (toolbar_view);
        }

        public DescriptionDialog (Models.Release release) {
            this.release = release;

            window_title.set_subtitle (release.displayed_title);
            description_label.set_label (release.description);
        }

        void web_button_clicked () {
            Utils.System.open_uri (release.page_url);
        }
    }
}
