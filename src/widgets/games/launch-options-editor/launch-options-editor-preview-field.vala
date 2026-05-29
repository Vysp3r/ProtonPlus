namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;

    class LaunchOptionPreviewField : Gtk.Box {
        public Gtk.Label preview_label { get; private set; }

        public LaunchOptionPreviewField (string title) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            var group = new PreferencesGroup ();
            group.title = title;

            preview_label = new Gtk.Label ("");
            preview_label.set_xalign (0);
            preview_label.set_yalign (0);
            preview_label.set_use_markup (true);
            preview_label.set_selectable (true);
            preview_label.set_wrap (false);
            preview_label.set_margin_start (12);
            preview_label.set_margin_end (12);
            preview_label.set_margin_top (12);
            preview_label.set_margin_bottom (12);

            var scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_min_content_height (56);
            scrolled_window.set_child (preview_label);
            scrolled_window.add_css_class ("card");
            scrolled_window.set_overflow (Gtk.Overflow.HIDDEN);

            group.add (scrolled_window);

            append (group);
        }
    }
}