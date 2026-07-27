namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    class LaunchOptionPreviewField : Gtk.Box {
        public Gtk.Label preview_label { get; private set; }
        Adw.ExpanderRow disclosure_row;
        Gtk.ScrolledWindow preview_scrolled_window;
        bool attention_required;

        public LaunchOptionPreviewField (string title) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            var group = new PreferencesGroup ();
            disclosure_row = new Adw.ExpanderRow () {
                title = title,
                subtitle = _("Show the exact command that will be saved to Steam."),
                expanded = false
            };
            disclosure_row.add_css_class ("launch-options-preview");
            disclosure_row.set_tooltip_text (disclosure_row.subtitle);

            preview_label = new Gtk.Label ("");
            preview_label.xalign = 0;
            preview_label.yalign = 0;
            preview_label.use_markup = true;
            preview_label.selectable = true;
            preview_label.wrap = true;
            preview_label.margin_start = 12;
            preview_label.margin_end = 12;
            preview_label.margin_top = 12;
            preview_label.margin_bottom = 12;

            preview_scrolled_window = new Gtk.ScrolledWindow ();
            preview_scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            preview_scrolled_window.set_max_content_height (180);
            preview_scrolled_window.set_propagate_natural_height (true);
            preview_scrolled_window.set_child (preview_label);
            preview_scrolled_window.add_css_class ("launch-options-preview-surface");
            preview_scrolled_window.set_overflow (Gtk.Overflow.HIDDEN);

            disclosure_row.add_row (preview_scrolled_window);
            group.add (disclosure_row);
            append (group);
        }

        public void set_empty (bool empty) {
            preview_label.halign = empty ? Gtk.Align.CENTER : Gtk.Align.FILL;
            preview_label.xalign = empty ? 0.5f : 0;

            if (empty) {
                preview_label.add_css_class ("dim-label");
                preview_label.add_css_class ("launch-options-preview-empty");
            } else {
                preview_label.remove_css_class ("dim-label");
                preview_label.remove_css_class ("launch-options-preview-empty");
            }
        }

        public void set_attention_required (bool required) {
            if (required && !attention_required)
                disclosure_row.expanded = true;

            attention_required = required;
            disclosure_row.subtitle = required
                ? _("Raw or unrecognized content needs attention before saving.")
                : _("Show the exact command that will be saved to Steam.");
            disclosure_row.set_tooltip_text (disclosure_row.subtitle);
        }
    }
}
