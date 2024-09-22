namespace ProtonPlus.Widgets {
    public abstract class Dialog : Adw.Window {
        protected Gtk.Box content_box { get; set; }
        protected Gtk.ScrolledWindow scrolled_window { get; set; }
        protected Gtk.ListBox list { get; set; }
        protected Gtk.Label progress_label { get; set; }
        public Gtk.Button close_button { get; set; }

        protected Models.Release release { get; set; }
        int count { get; set; }

        construct {
            progress_label = new Gtk.Label ("");

            list = new Gtk.ListBox ();
            list.add_css_class ("dialog-list");
            list.set_selection_mode (Gtk.SelectionMode.NONE);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (list);
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS);
            scrolled_window.set_size_request (200, 125);
            scrolled_window.add_css_class ("card");
            scrolled_window.add_css_class ("dialog");

            close_button = new Gtk.Button ();
            close_button.clicked.connect (close_button_clicked);

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content_box.set_margin_top (25);
            content_box.set_margin_bottom (25);
            content_box.set_margin_start (25);
            content_box.set_margin_end (25);
            content_box.append (scrolled_window);
            content_box.append (close_button);

            set_resizable (false);
            set_content (content_box);
            set_transient_for (Application.window);
            set_modal (true);
        }

        public virtual void initialize (Models.Release release) {
            this.release = release;
        }

        public virtual void reset () {
            count = 5;

            progress_label.set_text ("");

            list.remove_all ();

            close_button.set_label (_("Close"));
            close_button.set_sensitive (false);
        }

        public virtual void done (bool success) {
            close_button.set_sensitive (true);

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
            close_button.set_label ("%s (%i)".printf (_("Close"), count--));
        }

        public void add_text (string text) {
            var label = new Gtk.Label (text);
            list.append (label);
        }

        void close_button_clicked () {
            hide ();
        }
    }
}