namespace ProtonPlus.Widgets {
    public abstract class MangoHudPage : Gtk.Box {
        public Models.MangoHudConfig config { get; construct; }
        public bool is_updating { get; set; default = false; }

        public signal void changed ();

        protected MangoHudPage (Models.MangoHudConfig config) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12, config: config);
        }

        public abstract void refresh ();

        protected void add_group_to_page (Gtk.Box page, string? title, Gtk.Widget content, string title_class = "heading") {
            var group_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            if (title != null) {
                var label = new Gtk.Label (title) {
                    halign = Gtk.Align.START,
                    margin_start = 12
                };
                label.add_css_class (title_class);
                group_box.append (label);
            }
            group_box.append (content);
            page.append (group_box);
        }

        protected Gtk.Widget create_row_card (Gtk.ListBoxRow row) {
            var list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.append (row);
            var card = create_card_box ();
            card.append (list_box);
            return card;
        }

        protected Gtk.FlowBox create_flow_box () {
            return new Gtk.FlowBox () {
                valign = Gtk.Align.START,
                max_children_per_line = 3,
                min_children_per_line = 1,
                row_spacing = 12,
                column_spacing = 12,
                selection_mode = Gtk.SelectionMode.NONE,
            };
        }

        protected Gtk.Box create_card_box () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                valign = Gtk.Align.START,
                overflow = Gtk.Overflow.HIDDEN
            };
            box.add_css_class ("card");
            return box;
        }

        protected Gtk.ToggleButton create_preset_button (string label, string icon_name, ref Gtk.ToggleButton? group) {
            var button = new Gtk.ToggleButton ();
            if (group == null) {
                group = button;
            } else {
                button.set_group (group);
            }

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };
            var image = new Gtk.Image.from_icon_name (icon_name) {
                pixel_size = 24
            };
            var lbl = new Gtk.Label (label);

            box.append (image);
            box.append (lbl);

            button.set_child (box);
            button.add_css_class ("card");
            button.hexpand = true;

            return button;
        }
    }
}
