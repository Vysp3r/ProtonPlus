namespace ProtonPlus.Widgets {
    public class MangoHudVisualPage : MangoHudPage {
        private Adw.EntryRow hud_title_row;
        private Adw.ComboRow orientation_row;
        private Adw.ComboRow border_row;
        private Gtk.ColorDialogButton bg_color_btn;
        private Gtk.ColorDialogButton font_color_btn;
        private Adw.EntryRow font_size_row;
        private Adw.ComboRow position_row;
        private Adw.ComboRow columns_row;
        private Adw.ComboRow toggle_hud_row;
        private Adw.SwitchRow compact_row;
        private Adw.SwitchRow no_display_row;

        public MangoHudVisualPage (Models.MangoHudConfig config) {
            base (config);

            var visual_flow_box = create_flow_box ();

            hud_title_row = new Adw.EntryRow () {
                title = _ ("HUD Title"),
                text = config.hud_title
            };
            hud_title_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.hud_title = hud_title_row.text;
                config.save ();
            });

            orientation_row = new Adw.ComboRow () {
                title = _ ("Orientation"),
                icon_name = "object-flip-horizontal-symbolic",
                model = new Gtk.StringList ({_ ("Vertical"), _ ("Horizontal")}),
                selected = config.horizontal ? 1 : 0
            };
            orientation_row.notify["selected"].connect (() => {
                if (is_updating) return;
                config.horizontal = orientation_row.selected == 1;
                config.save ();
                changed ();
            });
            visual_flow_box.append (create_row_card (orientation_row));

            border_row = new Adw.ComboRow () {
                title = _ ("Borders"),
                icon_name = "view-grid-symbolic",
                model = new Gtk.StringList ({_ ("Squared"), _ ("Rounded")}),
                selected = config.round_corners > 0 ? 1 : 0
            };
            border_row.notify["selected"].connect (() => {
                if (is_updating) return;
                config.round_corners = border_row.selected == 1 ? 10 : 0;
                config.save ();
            });
            visual_flow_box.append (create_row_card (border_row));

            var color_dialog = new Gtk.ColorDialog ();
            var color_dialog_alpha = new Gtk.ColorDialog () {
                with_alpha = true
            };

            bg_color_btn = new Gtk.ColorDialogButton (color_dialog_alpha);
            bg_color_btn.set_valign (Gtk.Align.CENTER);
            var bg_rgba = Gdk.RGBA ();
            bg_rgba.parse ("#" + config.background_color);
            bg_rgba.alpha = float.parse (config.background_alpha);
            bg_color_btn.rgba = bg_rgba;

            var bg_color_row = new Adw.ActionRow () {
                title = _ ("Background Color"),
                icon_name = "fill-color-symbolic",
            };
            bg_color_row.add_suffix (bg_color_btn);
            visual_flow_box.append (create_row_card (bg_color_row));

            bg_color_btn.notify["rgba"].connect (() => {
                if (is_updating) return;
                var rgba = bg_color_btn.get_rgba ();
                config.background_color = "%02x%02x%02x".printf ((uint) (rgba.red * 255), (uint) (rgba.green * 255), (uint) (rgba.blue * 255));
                config.background_alpha = "%.1f".printf (rgba.alpha);
                config.save ();
            });

            font_color_btn = new Gtk.ColorDialogButton (color_dialog);
            font_color_btn.set_valign (Gtk.Align.CENTER);
            var font_rgba = Gdk.RGBA ();
            font_rgba.parse ("#" + config.text_color);
            font_color_btn.rgba = font_rgba;

            font_color_btn.notify["rgba"].connect (() => {
                if (is_updating) return;
                var rgba = font_color_btn.get_rgba ();
                config.text_color = "%02x%02x%02x".printf ((uint) (rgba.red * 255), (uint) (rgba.green * 255), (uint) (rgba.blue * 255));
                config.save ();
            });

            font_size_row = new Adw.EntryRow () {
                title = _ ("Font Size"),
                text = config.font_size
            };
            font_size_row.add_suffix (font_color_btn);
            font_size_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.font_size = font_size_row.text;
                config.save ();
            });
            visual_flow_box.append (create_row_card (font_size_row));

            position_row = new Adw.ComboRow () {
                title = _ ("Position"),
                icon_name = "view-fullscreen-symbolic",
                model = new Gtk.StringList ({_ ("Top Left"), _ ("Top Right"), _ ("Bottom Left"), _ ("Bottom Right")}),
            };
            refresh_position_row ();
            position_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (position_row.selected) {
                    case 0: config.position = "top-left"; break;
                    case 1: config.position = "top-right"; break;
                    case 2: config.position = "bottom-left"; break;
                    case 3: config.position = "bottom-right"; break;
                }
                config.save ();
            });
            visual_flow_box.append (create_row_card (position_row));

            columns_row = new Adw.ComboRow () {
                title = _ ("Columns"),
                icon_name = "view-column-symbolic",
                model = new Gtk.StringList ({"1", "2", "3", "4", "5", "6"}),
            };
            columns_row.selected = config.table_columns > 0 ? config.table_columns - 1 : 0;
            columns_row.notify["selected"].connect (() => {
                if (is_updating) return;
                config.table_columns = (int) columns_row.selected + 1;
                config.save ();
            });
            visual_flow_box.append (create_row_card (columns_row));

            toggle_hud_row = new Adw.ComboRow () {
                title = _ ("HUD Toggle Key"),
                icon_name = "preferences-desktop-keyboard-shortcuts-symbolic",
                model = new Gtk.StringList ({"Shift_R+F12", "Shift_R+F1", "Shift_R+F2", "Shift_R+F3", "Shift_R+F4", _ ("None")}),
            };
            refresh_toggle_hud_row ();
            toggle_hud_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (toggle_hud_row.selected) {
                    case 0: config.toggle_hud = "Shift_R+F12"; break;
                    case 1: config.toggle_hud = "Shift_R+F1"; break;
                    case 2: config.toggle_hud = "Shift_R+F2"; break;
                    case 3: config.toggle_hud = "Shift_R+F3"; break;
                    case 4: config.toggle_hud = "Shift_R+F4"; break;
                    case 5: config.toggle_hud = ""; break;
                }
                config.save ();
            });
            visual_flow_box.append (create_row_card (toggle_hud_row));

            compact_row = new Adw.SwitchRow () {
                title = _ ("Compact HUD"),
                icon_name = "view-compact-symbolic",
                active = config.compact
            };
            compact_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.compact = compact_row.active;
                config.save ();
            });
            visual_flow_box.append (create_row_card (compact_row));

            no_display_row = new Adw.SwitchRow () {
                title = _ ("Hide by default"),
                icon_name = "eye-not-looking-symbolic",
                active = config.no_display
            };
            no_display_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.no_display = no_display_row.active;
                config.save ();
            });
            visual_flow_box.append (create_row_card (no_display_row));

            add_group_to_page (this, null, create_row_card (hud_title_row));
            add_group_to_page (this, null, visual_flow_box);
        }

        private void refresh_position_row () {
            int pos_index = 0;
            switch (config.position) {
                case "top-left": pos_index = 0; break;
                case "top-right": pos_index = 1; break;
                case "bottom-left": pos_index = 2; break;
                case "bottom-right": pos_index = 3; break;
            }
            position_row.selected = pos_index;
        }

        private void refresh_toggle_hud_row () {
            int toggle_index = 5;
            switch (config.toggle_hud) {
                case "Shift_R+F12": toggle_index = 0; break;
                case "Shift_R+F1": toggle_index = 1; break;
                case "Shift_R+F2": toggle_index = 2; break;
                case "Shift_R+F3": toggle_index = 3; break;
                case "Shift_R+F4": toggle_index = 4; break;
                case "": toggle_index = 5; break;
            }
            toggle_hud_row.selected = toggle_index;
        }

        public override void refresh () {
            is_updating = true;
            hud_title_row.text = config.hud_title;
            orientation_row.selected = config.horizontal ? 1 : 0;
            border_row.selected = config.round_corners > 0 ? 1 : 0;
            
            var bg_rgba = Gdk.RGBA ();
            bg_rgba.parse ("#" + config.background_color);
            bg_rgba.alpha = float.parse (config.background_alpha);
            bg_color_btn.rgba = bg_rgba;

            var font_rgba = Gdk.RGBA ();
            font_rgba.parse ("#" + config.text_color);
            font_color_btn.rgba = font_rgba;

            font_size_row.text = config.font_size;
            refresh_position_row ();
            columns_row.selected = config.table_columns > 0 ? config.table_columns - 1 : 0;
            refresh_toggle_hud_row ();
            compact_row.active = config.compact;
            no_display_row.active = config.no_display;
            is_updating = false;
        }
    }
}
