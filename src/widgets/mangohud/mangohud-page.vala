namespace ProtonPlus.Widgets {
    public abstract class MangoHudPage : Gtk.Box {
        public Models.MangoHudConfig config { get; set; }
        public bool is_updating { get; set; default = false; }

        public signal void changed ();

        protected delegate void SetValueFunc (bool val);
        protected delegate void SetValueFuncStr (string val);
        protected delegate void SetValueFuncInt (int val);

        protected Gdk.RGBA hex_to_rgba (string hex, string default_color = "#ffffff") {
            var rgba = Gdk.RGBA ();
            if (hex != "") {
                if (!hex.has_prefix ("#")) {
                    rgba.parse ("#" + hex);
                } else {
                    rgba.parse (hex);
                }
            } else {
                rgba.parse (default_color);
            }
            return rgba;
        }

        protected string rgba_to_hex (Gdk.RGBA rgba) {
            return "%02x%02x%02x".printf (
                (uint) Math.round (rgba.red * 255.0),
                (uint) Math.round (rgba.green * 255.0),
                (uint) Math.round (rgba.blue * 255.0)
            );
        }

        protected Gtk.ColorDialogButton create_color_button (Gtk.ColorDialog dialog, string initial_color, SetValueFuncStr set_color) {
            var btn = new Gtk.ColorDialogButton (dialog);
            btn.set_valign (Gtk.Align.CENTER);
            btn.rgba = hex_to_rgba (initial_color);
            btn.notify["rgba"].connect (() => {
                if (is_updating || this.config == null) return;
                Gdk.RGBA rgba;
                btn.get ("rgba", out rgba);
                set_color (rgba_to_hex (rgba));
                changed ();
            });
            return btn;
        }

        protected Gtk.FlowBox add_flow_group (Gtk.Box page, string? title, Gtk.Widget[] widgets) {
            var flow_box = create_flow_box ();
            foreach (var widget in widgets) {
                if (widget is Gtk.ListBoxRow) {
                    flow_box.append (create_row_card ((Gtk.ListBoxRow) widget));
                } else {
                    flow_box.append (widget);
                }
            }
            add_group_to_page (page, title, flow_box, "caption");
            return flow_box;
        }

        protected MangoHudPage (Models.MangoHudConfig config) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            this.config = config;
            this.set_hexpand (true);
        }

        public abstract void refresh ();

        protected Adw.EntryRow create_entry (string title, string initial_value, SetValueFuncStr set_value) {
            var row = new Adw.EntryRow () {
                title = title,
                text = initial_value
            };
            row.notify["text"].connect (() => {
                if (is_updating || this.config == null) return;
                set_value (row.text);
                changed ();
            });
            return row;
        }

        protected Adw.ComboRow create_combo (string title, string[] items, int initial_selected, string? icon_name, SetValueFuncInt set_value) {
            var row = new Adw.ComboRow () {
                title = title,
                icon_name = icon_name,
                model = new Gtk.StringList (items),
                selected = initial_selected
            };
            row.notify["selected"].connect (() => {
                if (is_updating || this.config == null) return;
                set_value ((int) row.selected);
                changed ();
            });
            return row;
        }

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

        protected Gtk.ListBoxRow create_scale (string title, double min, double max, double step, out Gtk.Scale scale_out, SetValueFuncStr set_value) {
            var row = new Gtk.ListBoxRow ();
            row.selectable = false;

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };

            var label = new Gtk.Label (title) {
                halign = Gtk.Align.START,
                hexpand = true
            };
            box.append (label);

            var scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step) {
                hexpand = true,
                draw_value = true,
                value_pos = Gtk.PositionType.BOTTOM
            };
            scale.add_mark (min, Gtk.PositionType.TOP, "%.0f".printf (min));
            scale.add_mark (max, Gtk.PositionType.TOP, "%.0f".printf (max));
            scale.value_changed.connect (() => {
                if (is_updating || this.config == null) return;
                set_value ("%.0f".printf (scale.get_value ()));
                changed ();
            });
            box.append (scale);
            row.set_child (box);
            scale_out = scale;
            return row;
        }

        protected Adw.SwitchRow create_switch (string title, bool initial_value, SetValueFunc set_value) {
            var row = new Adw.SwitchRow () {
                title = title,
                active = initial_value
            };
            row.notify["active"].connect (() => {
                if (is_updating || this.config == null) return;
                set_value (row.active);
                changed ();
            });
            return row;
        }
    }
}
