namespace ProtonPlus.Widgets.MangoHud {
    public class VisualPage : Page {
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

        public VisualPage (Models.MangoHudConfig config) {
            base (config);

            hud_title_row = create_entry (_ ("HUD Title"), config.hud_title, (val) => { this.config.hud_title = val; });
            add_group_to_page (this, null, create_row_card (hud_title_row));

            orientation_row = create_combo (_ ("Orientation"), {_ ("Vertical"), _ ("Horizontal")}, config.horizontal ? 1 : 0, "object-flip-horizontal-symbolic", (val) => {
                this.config.horizontal = val == 1;
            });

            border_row = create_combo (_ ("Borders"), {_ ("Squared"), _ ("Rounded")}, config.round_corners > 0 ? 1 : 0, "view-grid-symbolic", (val) => {
                this.config.round_corners = val == 1 ? 10 : 0;
            });

            var color_dialog = new Gtk.ColorDialog ();
            var color_dialog_alpha = new Gtk.ColorDialog () {
                with_alpha = true
            };

            bg_color_btn = new Gtk.ColorDialogButton (color_dialog_alpha);
            bg_color_btn.set_valign (Gtk.Align.CENTER);
            var bg_rgba = hex_to_rgba (config.background_color);
            bg_rgba.alpha = float.parse (config.background_alpha);
            bg_color_btn.rgba = bg_rgba;

            var bg_color_row = new Adw.ActionRow () {
                title = _ ("Background Color"),
                icon_name = "fill-color-symbolic",
            };
            bg_color_row.add_suffix (bg_color_btn);

            bg_color_btn.notify["rgba"].connect (() => {
                if (is_updating || this.config == null) return;
                Gdk.RGBA rgba;
                bg_color_btn.get ("rgba", out rgba);
                this.config.background_color = rgba_to_hex (rgba);
                this.config.background_alpha = "%.1f".printf (rgba.alpha);
                changed ();
            });

            font_color_btn = create_color_button (color_dialog, config.text_color, (val) => { this.config.text_color = val; });

            font_size_row = create_entry (_ ("Font Size"), config.font_size, (val) => { this.config.font_size = val; });
            font_size_row.add_suffix (font_color_btn);

            position_row = create_combo (_ ("Position"), {_ ("Top Left"), _ ("Top Right"), _ ("Bottom Left"), _ ("Bottom Right")}, 0, "view-fullscreen-symbolic", (val) => {
                switch (val) {
                    case 0: this.config.position = "top-left"; break;
                    case 1: this.config.position = "top-right"; break;
                    case 2: this.config.position = "bottom-left"; break;
                    case 3: this.config.position = "bottom-right"; break;
                }
            });
            refresh_position_row ();

            columns_row = create_combo (_ ("Columns"), {"1", "2", "3", "4", "5", "6"}, config.table_columns > 0 ? config.table_columns - 1 : 0, "view-column-symbolic", (val) => {
                this.config.table_columns = val + 1;
            });

            toggle_hud_row = create_combo (_ ("HUD Toggle Key"), {"Shift_R+F12", "Shift_R+F1", "Shift_R+F2", "Shift_R+F3", "Shift_R+F4", _ ("None")}, 0, "preferences-desktop-keyboard-shortcuts-symbolic", (val) => {
                switch (val) {
                    case 0: this.config.toggle_hud = "Shift_R+F12"; break;
                    case 1: this.config.toggle_hud = "Shift_R+F1"; break;
                    case 2: this.config.toggle_hud = "Shift_R+F2"; break;
                    case 3: this.config.toggle_hud = "Shift_R+F3"; break;
                    case 4: this.config.toggle_hud = "Shift_R+F4"; break;
                    case 5: this.config.toggle_hud = ""; break;
                }
            });
            refresh_toggle_hud_row ();

            compact_row = create_switch (_ ("Compact HUD"), config.compact, (val) => { this.config.compact = val; }, "view-compact-symbolic");

            no_display_row = create_switch (_ ("Hide by default"), config.no_display, (val) => { this.config.no_display = val; }, "eye-not-looking-symbolic");

            add_flow_group (this, null, {
                                            orientation_row, border_row, bg_color_row, font_size_row, position_row, columns_row, toggle_hud_row, compact_row, no_display_row
                                        });
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

            var bg_rgba_ref = hex_to_rgba (config.background_color);
            bg_rgba_ref.alpha = float.parse (config.background_alpha);
            bg_color_btn.rgba = bg_rgba_ref;

            font_color_btn.rgba = hex_to_rgba (config.text_color);

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
