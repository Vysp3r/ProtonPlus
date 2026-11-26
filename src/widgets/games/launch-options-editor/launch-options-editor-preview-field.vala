namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    class LaunchOptionPreviewField : Gtk.Box {
        public Gtk.Label preview_label { get; private set; }
        public Gtk.ToggleButton button { get; private set; }
        public string blocking_reason { get; set; default = ""; }

        public LaunchOptionPreviewField () {
            Object (orientation: Gtk.Orientation.VERTICAL);
            var revealer = new Gtk.Revealer ();
            button = new Gtk.ToggleButton.with_label (_("Command preview"));
            button.bind_property ("active", revealer, "reveal-child", BindingFlags.SYNC_CREATE);
            preview_label = new Gtk.Label ("") {
                xalign = 0, yalign = 0, use_markup = true, selectable = true,
                wrap = true, wrap_mode = Pango.WrapMode.WORD_CHAR,
                margin_start = 12, margin_end = 12, margin_top = 8, margin_bottom = 8
            };

            revealer.child = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                max_content_height = 132, propagate_natural_height = true,
                child = preview_label, css_classes = { "launch-options-preview-surface" }
            };
            append (revealer);
        }

        public void collapse () {
            button.active = false;
        }

        public void set_empty (bool empty) {
            if (empty)
                preview_label.add_css_class ("dim-label");
            else
                preview_label.remove_css_class ("dim-label");
        }
    }
}
