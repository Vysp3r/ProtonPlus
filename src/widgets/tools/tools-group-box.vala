namespace ProtonPlus.Widgets.Tools {
    public class GroupBox : Gtk.Box {
        public signal void tool_selected (Models.Tool tool);

        public GroupBox (Models.Group group) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            var icon = new Gtk.Image.from_icon_name ("layer-group-symbolic");

            var title_label = new Gtk.Label (group.title) {
                halign = Gtk.Align.START,
                css_classes = { "title-4" }
            };

            var desc_label = new Gtk.Label (group.description) {
                halign = Gtk.Align.START,
                css_classes = { "caption" },
                wrap = true,
                xalign = 0
            };

            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            title_box.append (title_label);
            title_box.append (desc_label);

            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.append (icon);
            header_box.append (title_box);

            var list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-tools-card");

            var scrolled = new Gtk.ScrolledWindow () {
                child = list_box,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC
            };

            foreach (var tool in group.tools) {
                list_box.append (create_tool_card (tool));
            }

            var group_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            group_box.add_css_class ("card");
            group_box.add_css_class ("tools-group-card");
            group_box.append (header_box);
            group_box.append (scrolled);

            var clamp = new Adw.Clamp () {
                maximum_size = 975,
                margin_top = 5,
                margin_bottom = 12,
                child = group_box,
            };

            append (clamp);
        }

        Adw.ActionRow create_tool_card (Models.Tool tool) {
            var icon = new Gtk.Image.from_icon_name ("box-open-symbolic");

            var row = new Adw.ActionRow () {
                title = tool.title,
                subtitle = tool.description,
                activatable = true,
            };
            row.activated.connect (() => tool_selected (tool));
            row.add_prefix (icon);

            return row;
        }
    }
}