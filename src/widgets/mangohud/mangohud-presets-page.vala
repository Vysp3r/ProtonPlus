namespace ProtonPlus.Widgets {
    public class MangoHudPresetsPage : MangoHudPage {
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

        public MangoHudPresetsPage (Models.MangoHudConfig config) {
            base (config);

            var presets_flow_box = create_flow_box ();

            preset_buttons = new Gtk.ToggleButton[5];
            Gtk.ToggleButton? preset_group_button = null;

            preset_full_btn = create_preset_button (_ ("Full"), "chart-area-symbolic", ref preset_group_button);
            preset_basic_btn = create_preset_button (_ ("Basic"), "square-poll-vertical-symbolic", ref preset_group_button);
            preset_basic_horiz_btn = create_preset_button (_ ("Basic Horizontal"), "square-poll-horizontal-symbolic", ref preset_group_button);
            preset_fps_only_btn = create_preset_button (_ ("FPS Only"), "gauge-high-symbolic", ref preset_group_button);
            preset_custom_btn = create_preset_button (_ ("Custom"), "gear-symbolic", ref preset_group_button);

            preset_buttons[Models.MangoHudPreset.FULL] = preset_full_btn;
            preset_buttons[Models.MangoHudPreset.BASIC] = preset_basic_btn;
            preset_buttons[Models.MangoHudPreset.BASIC_HORIZONTAL] = preset_basic_horiz_btn;
            preset_buttons[Models.MangoHudPreset.FPS_ONLY] = preset_fps_only_btn;
            preset_buttons[Models.MangoHudPreset.CUSTOM] = preset_custom_btn;

            presets_flow_box.append (preset_full_btn);
            presets_flow_box.append (preset_basic_btn);
            presets_flow_box.append (preset_basic_horiz_btn);
            presets_flow_box.append (preset_fps_only_btn);
            presets_flow_box.append (preset_custom_btn);

            preset_custom_btn.toggled.connect (() => { if (!is_updating && preset_custom_btn.active) apply_preset (Models.MangoHudPreset.CUSTOM); });
            preset_full_btn.toggled.connect (() => { if (!is_updating && preset_full_btn.active) apply_preset (Models.MangoHudPreset.FULL); });
            preset_basic_btn.toggled.connect (() => { if (!is_updating && preset_basic_btn.active) apply_preset (Models.MangoHudPreset.BASIC); });
            preset_basic_horiz_btn.toggled.connect (() => { if (!is_updating && preset_basic_horiz_btn.active) apply_preset (Models.MangoHudPreset.BASIC_HORIZONTAL); });
            preset_fps_only_btn.toggled.connect (() => { if (!is_updating && preset_fps_only_btn.active) apply_preset (Models.MangoHudPreset.FPS_ONLY); });

            add_group_to_page (this, _ ("Layouts"), presets_flow_box);

            var themes_flow_box = create_flow_box ();
            theme_buttons = new Gtk.ToggleButton[3];
            Gtk.ToggleButton? theme_group_button = null;

            theme_stock_btn = create_preset_button (_ ("MangoHud Stock"), "boxes-stacked-symbolic", ref theme_group_button);
            theme_white_btn = create_preset_button (_ ("Simple White"), "layer-group-symbolic", ref theme_group_button);
            theme_custom_btn = create_preset_button (_ ("Custom"), "gear-symbolic", ref theme_group_button);

            theme_buttons[Models.MangoHudTheme.STOCK] = theme_stock_btn;
            theme_buttons[Models.MangoHudTheme.SIMPLE_WHITE] = theme_white_btn;
            theme_buttons[Models.MangoHudTheme.CUSTOM] = theme_custom_btn;

            themes_flow_box.append (theme_stock_btn);
            themes_flow_box.append (theme_white_btn);
            themes_flow_box.append (theme_custom_btn);

            theme_stock_btn.toggled.connect (() => { if (!is_updating && theme_stock_btn.active) apply_theme (Models.MangoHudTheme.STOCK); });
            theme_white_btn.toggled.connect (() => { if (!is_updating && theme_white_btn.active) apply_theme (Models.MangoHudTheme.SIMPLE_WHITE); });
            theme_custom_btn.toggled.connect (() => { if (!is_updating && theme_custom_btn.active) apply_theme (Models.MangoHudTheme.CUSTOM); });

            add_group_to_page (this, _ ("Color Themes"), themes_flow_box);
            refresh ();
        }

        private void apply_preset (Models.MangoHudPreset preset) {
            if (is_updating || this.config == null || preset == Models.MangoHudPreset.CUSTOM) return;

            is_updating = true;
            this.config.set_preset (preset);
            is_updating = false;
            
            changed (); // Notify MangoHudBox to refresh other pages
        }

        private void apply_theme (Models.MangoHudTheme theme) {
            if (is_updating || this.config == null || theme == Models.MangoHudTheme.CUSTOM) return;

            is_updating = true;
            this.config.set_theme (theme);
            is_updating = false;

            changed (); // Notify MangoHudBox to refresh other pages
        }

        public override void refresh () {
            if (this.config == null) return;
            var selected_preset = (int) this.config.get_preset ();
            var selected_theme = (int) this.config.get_theme ();
            is_updating = true;
            preset_buttons[selected_preset].active = true;
            theme_buttons[selected_theme].active = true;
            is_updating = false;
        }
    }
}
