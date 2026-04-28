namespace ProtonPlus.Widgets.Tools {
    public class ReleaseBox : Gtk.Box {
        Gtk.Box tool_box { get; set; }
        Gtk.Label title_label { get; set; }
        Gtk.Label desc_label { get; set; }
        Gtk.TextView desc_text { get; set; }
        Gtk.Box header_box { get; set; }
        Gtk.ListBox list_box { get; set; }
        Gtk.Stack content_stack { get; set; }

        public ReleaseBox () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            var icon = new Gtk.Image.from_icon_name ("box-open-symbolic");

            title_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                css_classes = { "title-4" }
            };

            desc_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                css_classes = { "subtitle" }
            };

            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true
            };
            title_box.append (title_label);
            title_box.append (desc_label);

            header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.append (icon);
            header_box.append (title_box);

            desc_text = new Gtk.TextView () {
                editable = false,
                cursor_visible = false,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                left_margin = 12,
                right_margin = 12,
                top_margin = 12,
                bottom_margin = 12
            };

            var scrolled = new Gtk.ScrolledWindow () {
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                child = desc_text,
                css_classes = { "card" },
                overflow = Gtk.Overflow.HIDDEN
            };

            tool_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            tool_box.append (header_box);
            tool_box.append (scrolled);

            var clamp = new Adw.Clamp () {
                maximum_size = 975,
                margin_top = 5,
                margin_bottom = 12,
                child = tool_box,
            };

            append (clamp);
        }

        public void set_selected_release (Models.Release release) {
            title_label.set_label (release.title ?? "");
            desc_text.buffer.text = release.description ?? "";
            desc_label.set_label (release.release_date ?? "");
        }
    }
}
