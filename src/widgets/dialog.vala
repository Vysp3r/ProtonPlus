namespace ProtonPlus.Widgets {
    public abstract class Dialog : Adw.Window {
        protected Gtk.Box content_box { get; set; }
        protected Gtk.ScrolledWindow scrolled_window { get; set; }
        protected Gtk.Label label { get; set; }
        public Gtk.Button close_buttton { get; set; }

        int count { get; set; }

        construct {
            label = new Gtk.Label ("");
            label.set_valign (Gtk.Align.START);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (label);
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS);
            scrolled_window.set_size_request (100, 100);
            scrolled_window.add_css_class ("card");
            scrolled_window.add_css_class ("console-dialog");

            close_buttton = new Gtk.Button ();
            close_buttton.clicked.connect (close_button_clicked);

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content_box.set_margin_top (25);
            content_box.set_margin_bottom (25);
            content_box.set_margin_start (25);
            content_box.set_margin_end (25);
            content_box.append (scrolled_window);
            content_box.append (close_buttton);

            set_resizable (false);
            set_content (content_box);
            set_transient_for (Application.window);
            set_modal (true);
        }

        public virtual void reset () {
            count = 5;

            label.set_text ("");

            close_buttton.set_label (_("Close"));
            close_buttton.set_sensitive (false);
        }

        public virtual void done (bool success) {
            close_buttton.set_sensitive (true);

            if (success) {
                refresh_close_button_label ();

                GLib.Timeout.add_seconds_full (Priority.DEFAULT, 1, () => {
                    if (count == 0) {
                        hide ();
                        return false;
                    }

                    refresh_close_button_label ();

                    return true;
                });
            }
        }

        void refresh_close_button_label () {
            close_buttton.set_label ("%s (%i)".printf (_("Close"), count--));
        }

        public void add_text (string text) {
            var current_text = label.get_text ();
            if (current_text == "")
                label.set_text ("%s".printf (text));
            else
                label.set_text ("%s\n%s".printf (current_text, text));
        }

        void close_button_clicked () {
            hide ();
        }
    }
}