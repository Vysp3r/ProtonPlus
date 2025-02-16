namespace ProtonPlus.Widgets {
    public abstract class BusyDialog : Adw.Dialog {
        protected Adw.ToolbarView toolbar_view { get; set; }
        protected Adw.WindowTitle window_title { get; set; }
        protected Adw.HeaderBar header_bar { get; set; }
        protected Gtk.Box content_box { get; set; }
        protected Gtk.ScrolledWindow scrolled_window { get; set; }
        protected Gtk.Box container { get; set; }
        protected Gtk.Label progress_label { get; set; }
        protected Gtk.Label closing_label { get; set; }
        protected Gtk.ProgressBar progress_bar { get; set; }

        protected Models.Release release { get; set; }
        protected bool pulse { get; set; }
        protected bool finished { get; set; }
        protected bool stop { get; set; }
        protected int count { get; set; }

        construct {
            window_title = new Adw.WindowTitle ("", "");

            var log_button = new Gtk.Button.from_icon_name ("journal-text-symbolic");
            log_button.set_tooltip_text (_("Show/hide logs"));
            log_button.clicked.connect (() => {
                if (scrolled_window.get_parent () == null)
                    content_box.prepend (scrolled_window);
                else
                    content_box.remove (scrolled_window);
            });

            header_bar = new Adw.HeaderBar ();
            header_bar.set_title_widget (window_title);
            header_bar.pack_start (log_button);

            progress_label = new Gtk.Label ("");

            closing_label = new Gtk.Label ("");

            container = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (container);
            scrolled_window.set_size_request (200, 125);
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.add_css_class ("card");
            scrolled_window.add_css_class ("dialog");
            scrolled_window.get_vadjustment ().changed.connect (scroll_to_bottom);

            progress_bar = new Gtk.ProgressBar ();
            progress_bar.set_hexpand (true);
            progress_bar.set_vexpand (true);
            progress_bar.set_valign (Gtk.Align.CENTER);
            progress_bar.set_show_text (true);

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            content_box.set_margin_bottom (12);
            content_box.set_margin_start (12);
            content_box.set_margin_end (12);
            content_box.append (progress_bar);

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (content_box);

            closed.connect (dialog_on_close);

            set_child (toolbar_view);
        }

        protected void initialize (Models.Release release) {
            this.release = release;

            header_bar.set_show_end_title_buttons (false);

            window_title.set_subtitle (release.displayed_title);

            Timeout.add_full (Priority.DEFAULT, 25, () => {
                if (finished || stop)
                    return false;

                if (pulse)progress_bar.pulse ();

                return true;
            });
        }

        protected void dialog_on_close () {
            stop = true;
        }

        public virtual void done (bool success) {
            header_bar.set_show_end_title_buttons (true);

            finished = true;
            pulse = false;
            progress_bar.set_fraction (1);

            if (success) {
                count = 5;

                refresh_closing_label ();

                GLib.Timeout.add_seconds_full (Priority.DEFAULT, 1, () => {
                    if (stop)
                        return false;

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
                container.append (closing_label);
        }

        public void add_text (string text) {
            var label = new Gtk.Label (text);
            container.append (label);
            progress_bar.set_text (text);
        }

        void scroll_to_bottom () {
            var adjustment = scrolled_window.get_vadjustment ();
            adjustment.set_value (adjustment.get_upper () - adjustment.get_page_size ());
        }
    }
}