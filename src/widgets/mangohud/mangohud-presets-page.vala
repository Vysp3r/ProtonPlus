namespace ProtonPlus.Widgets.MangoHud {
    public class PresetsPage : Page {
        private Gtk.ToggleButton[] preset_buttons;
        private Gtk.ToggleButton preset_custom_btn;
        private Gtk.ToggleButton preset_full_btn;
        private Gtk.ToggleButton preset_basic_btn;
        private Gtk.ToggleButton preset_basic_horiz_btn;
        private Gtk.ToggleButton preset_fps_only_btn;
        private Gtk.ToggleButton[] theme_buttons;
        private Gtk.ToggleButton theme_stock_btn;
        private Gtk.ToggleButton theme_white_btn;
        private Gtk.ToggleButton theme_custom_btn;

        public PresetsPage (Utils.MangoHudManager config) {
            base (config);

            var presets_flow_box = create_flow_box ();

            preset_buttons = new Gtk.ToggleButton[5];
            Gtk.ToggleButton? preset_group_button = null;

            preset_full_btn = create_preset_button (_ ("Full"), "chart-area-symbolic", ref preset_group_button);
            preset_basic_btn = create_preset_button (_ ("Basic"), "square-poll-vertical-symbolic", ref preset_group_button);
            preset_basic_horiz_btn = create_preset_button (_ ("Basic Horizontal"), "square-poll-horizontal-symbolic", ref preset_group_button);
            preset_fps_only_btn = create_preset_button (_ ("FPS Only"), "gauge-high-symbolic", ref preset_group_button);
            preset_custom_btn = create_preset_button (_ ("Custom"), "gear-symbolic", ref preset_group_button);

            preset_buttons[Utils.MangoHudPreset.FULL] = preset_full_btn;
            preset_buttons[Utils.MangoHudPreset.BASIC] = preset_basic_btn;
            preset_buttons[Utils.MangoHudPreset.BASIC_HORIZONTAL] = preset_basic_horiz_btn;
            preset_buttons[Utils.MangoHudPreset.FPS_ONLY] = preset_fps_only_btn;
            preset_buttons[Utils.MangoHudPreset.CUSTOM] = preset_custom_btn;

            presets_flow_box.append (preset_full_btn);
            presets_flow_box.append (preset_basic_btn);
            presets_flow_box.append (preset_basic_horiz_btn);
            presets_flow_box.append (preset_fps_only_btn);
            presets_flow_box.append (preset_custom_btn);

            connect_preset_button (preset_custom_btn, Utils.MangoHudPreset.CUSTOM);
            connect_preset_button (preset_full_btn, Utils.MangoHudPreset.FULL);
            connect_preset_button (preset_basic_btn, Utils.MangoHudPreset.BASIC);
            connect_preset_button (preset_basic_horiz_btn, Utils.MangoHudPreset.BASIC_HORIZONTAL);
            connect_preset_button (preset_fps_only_btn, Utils.MangoHudPreset.FPS_ONLY);

            add_group_to_page (this, _ ("Layouts"), presets_flow_box);

            var themes_flow_box = create_flow_box ();
            theme_buttons = new Gtk.ToggleButton[3];
            Gtk.ToggleButton? theme_group_button = null;

            theme_stock_btn = create_preset_button (_ ("Stock"), "palette-2-symbolic", ref theme_group_button);
            theme_white_btn = create_preset_button (_ ("White"), "palette-2-symbolic", ref theme_group_button);
            theme_custom_btn = create_preset_button (_ ("Custom"), "gear-symbolic", ref theme_group_button);

            theme_buttons[Utils.MangoHudTheme.STOCK] = theme_stock_btn;
            theme_buttons[Utils.MangoHudTheme.SIMPLE_WHITE] = theme_white_btn;
            theme_buttons[Utils.MangoHudTheme.CUSTOM] = theme_custom_btn;

            themes_flow_box.append (theme_stock_btn);
            themes_flow_box.append (theme_white_btn);
            themes_flow_box.append (theme_custom_btn);

            connect_theme_button (theme_stock_btn, Utils.MangoHudTheme.STOCK);
            connect_theme_button (theme_white_btn, Utils.MangoHudTheme.SIMPLE_WHITE);
            connect_theme_button (theme_custom_btn, Utils.MangoHudTheme.CUSTOM);

            add_group_to_page (this, _ ("Themes"), themes_flow_box);
            refresh ();
        }

        private void connect_preset_button (Gtk.ToggleButton button, Utils.MangoHudPreset preset) {
            button.toggled.connect (() => {
                if (!is_updating && button.active)
                    apply_preset (preset);
            });
        }

        private void connect_theme_button (Gtk.ToggleButton button, Utils.MangoHudTheme theme) {
            button.toggled.connect (() => {
                if (!is_updating && button.active)
                    apply_theme (theme);
            });
        }

        private void apply_preset (Utils.MangoHudPreset preset) {
            if (is_updating || this.config == null || preset == Utils.MangoHudPreset.CUSTOM)
                return;

            is_updating = true;
            this.config.set_preset (preset);
            is_updating = false;

            changed (); // Notify MangoHudBox to refresh other pages
        }

        private void apply_theme (Utils.MangoHudTheme theme) {
            if (is_updating || this.config == null || theme == Utils.MangoHudTheme.CUSTOM)
                return;

            is_updating = true;
            this.config.set_theme (theme);
            is_updating = false;

            changed (); // Notify MangoHudBox to refresh other pages
        }

        public override void refresh () {
            if (this.config == null)
                return;

            var selected_preset = (int) this.config.get_preset ();
            var selected_theme = (int) this.config.get_theme ();
            is_updating = true;
            preset_buttons[selected_preset].active = true;
            theme_buttons[selected_theme].active = true;
            is_updating = false;
        }
    }
}
