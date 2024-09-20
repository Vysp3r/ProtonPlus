namespace ProtonPlus.Widgets {
    public abstract class Dialog : Adw.Window {
        internal Gtk.Box content_box { get; set; }
        internal Gtk.ScrolledWindow scrolled_window { get; set; }
        internal Gtk.Label label { get; set; }

        public string progress_text { get; set; }

        construct {
            label = new Gtk.Label ("");

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (label);
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS);
            scrolled_window.set_size_request (100, 100);
            scrolled_window.set_overlay_scrolling (false);
            scrolled_window.add_css_class ("card");
            scrolled_window.add_css_class ("console-dialog");

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content_box.set_margin_top (25);
            content_box.set_margin_bottom (25);
            content_box.set_margin_start (25);
            content_box.set_margin_end (25);
            content_box.append (scrolled_window);

            set_resizable (false);
            set_content (content_box);
            set_transient_for (Application.window);
            set_modal (true);

            notify["progress-text"].connect (progress_text_changed);
        }

        public void add_text (string text) {
            var current_text = label.get_text ();
            label.set_text ("%s%s\n".printf (current_text, text));
        }

        public void reset () {
            label.set_text ("");
        }

        void progress_text_changed () {
            var current_text = label.get_text ();
            if (!current_text.contains (progress_text))
                label.set_text ("%s%s\n".printf (current_text, progress_text));
        }
    }
}