namespace ProtonPlus.Widgets.Main {
    public class ErrorDialog : Adw.AlertDialog {
        public ErrorDialog (string heading, string body, string error) {
            set_heading (heading);
            set_body (body);

            if (error != "") {
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

                var label = new Gtk.Label (_ ("Technical Details"));
                label.halign = Gtk.Align.START;
                label.add_css_class ("caption");
                label.add_css_class ("dim-label");

                var scrolled = new Gtk.ScrolledWindow ();
                scrolled.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
                scrolled.set_min_content_height (100);
                scrolled.set_max_content_height (300);
                scrolled.set_vexpand (true);
                scrolled.add_css_class ("card");

                var text_view = new Gtk.TextView ();
                text_view.editable = false;
                text_view.cursor_visible = false;
                text_view.wrap_mode = Gtk.WrapMode.WORD_CHAR;
                text_view.set_margin_top (12);
                text_view.set_margin_bottom (12);
                text_view.set_margin_start (12);
                text_view.set_margin_end (12);
                text_view.buffer.text = error;
                text_view.add_css_class ("monospace");

                scrolled.set_child (text_view);

                box.append (label);
                box.append (scrolled);

                set_extra_child (box);
            }

            add_response ("report", _ ("Report"));
            set_response_appearance ("report", Adw.ResponseAppearance.SUGGESTED);

            add_response ("ok", _ ("OK"));
            set_response_appearance ("ok", Adw.ResponseAppearance.DEFAULT);

            response.connect ((response) => {
                if (response == "report")
                activate_action ("app.report", null);
            });
        }
    }
}