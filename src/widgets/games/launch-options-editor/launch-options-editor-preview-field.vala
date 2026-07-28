namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    class LaunchOptionPreviewField : Adw.ExpanderRow {
        public Gtk.Label preview_label { get; private set; }
        Gtk.ScrolledWindow preview_scrolled_window;
        bool attention_required;

        public LaunchOptionPreviewField (string title) {
            Object (
                title: title,
                subtitle: _("Show the exact command that will be saved to Steam."),
                expanded: false
            );
            add_css_class ("launch-options-preview");
            set_tooltip_text (subtitle);

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
            preview_scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.NEVER);
            preview_scrolled_window.set_propagate_natural_height (true);
            preview_scrolled_window.set_child (preview_label);
            preview_scrolled_window.add_css_class ("launch-options-preview-surface");
            preview_scrolled_window.set_overflow (Gtk.Overflow.HIDDEN);

            add_row (preview_scrolled_window);
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

        public void set_attention_required (bool required, string reason = "") {
            if (required && !attention_required)
                expanded = true;

            attention_required = required;
            subtitle = required
                ? (reason != "" ? reason : _("Raw or unrecognized content needs attention before saving."))
                : _("Show the exact command that will be saved to Steam.");
            set_tooltip_text (subtitle);
        }
    }
}
