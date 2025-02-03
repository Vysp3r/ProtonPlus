namespace ProtonPlus.Widgets {
    public abstract class BusyDialog : Adw.Window {
        protected Adw.ToolbarView toolbar_view { get; set; }
        protected Adw.WindowTitle window_title { get; set; }
        protected Adw.HeaderBar header_bar { get; set; }
        protected Gtk.Box content_box { get; set; }
        protected Gtk.ScrolledWindow scrolled_window { get; set; }
        protected Gtk.ListBox list { get; set; }
        protected Gtk.Label progress_label { get; set; }
        protected Gtk.Label closing_label { get; set; }

        protected Models.Release release { get; set; }
        int count { get; set; }

        construct {
            window_title = new Adw.WindowTitle ("", "");

            header_bar = new Adw.HeaderBar ();
            header_bar.set_title_widget (window_title);

            progress_label = new Gtk.Label ("");

            closing_label = new Gtk.Label ("");

            list = new Gtk.ListBox ();
            list.add_css_class ("dialog-list");
            list.set_selection_mode (Gtk.SelectionMode.NONE);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (list);
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS);
            scrolled_window.set_size_request (200, 125);
            scrolled_window.add_css_class ("card");
            scrolled_window.add_css_class ("dialog");

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            content_box.set_margin_top (7);
            content_box.set_margin_bottom (12);
            content_box.set_margin_start (12);
            content_box.set_margin_end (12);
            content_box.append (scrolled_window);

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (content_box);

            set_resizable (false);
            set_content (toolbar_view);
            set_transient_for (Application.window);
            set_modal (true);
        }

        public virtual void initialize (Models.Release release) {
            this.release = release;

            header_bar.set_show_end_title_buttons (false);

            window_title.set_subtitle (release.displayed_title);
        }

        public virtual void done (bool success) {
            header_bar.set_show_end_title_buttons (true);

            if (success) {
                count = 5;

                refresh_closing_label ();

                GLib.Timeout.add_seconds_full (Priority.DEFAULT, 1, () => {
                    if (count == 0) {
                        close ();
                        return false;
                    }

                    refresh_closing_label ();

                    return true;
                });
            }
        }

        void refresh_closing_label () {
            closing_label.set_text ("%s %i".printf (_("Closing in"), count--));
            if (closing_label.get_parent () == null)
                list.append (closing_label);
        }

        public void add_text (string text) {
            var label = new Gtk.Label (text);
            list.append (label);
        }
    }
}