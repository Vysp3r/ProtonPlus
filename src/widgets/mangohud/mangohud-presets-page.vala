namespace ProtonPlus.Widgets {
    public class MangoHudPresetsPage : MangoHudPage {
        private Gtk.ToggleButton[] preset_buttons;
        private Gtk.ToggleButton preset_custom_btn;
        private Gtk.ToggleButton preset_full_btn;
        private Gtk.ToggleButton preset_basic_btn;
        private Gtk.ToggleButton preset_basic_horiz_btn;
        private Gtk.ToggleButton preset_fps_only_btn;

        public MangoHudPresetsPage (Models.MangoHudConfig config) {
            base (config);

            var presets_flow_box = create_flow_box ();

            preset_buttons = new Gtk.ToggleButton[5];
            Gtk.ToggleButton? preset_group_button = null;

            preset_full_btn = create_preset_button (_ ("Full"), "view-fullscreen-symbolic", ref preset_group_button);
            preset_basic_btn = create_preset_button (_ ("Basic"), "view-list-symbolic", ref preset_group_button);
            preset_basic_horiz_btn = create_preset_button (_ ("Basic Horizontal"), "view-column-symbolic", ref preset_group_button);
            preset_fps_only_btn = create_preset_button (_ ("FPS Only"), "speedometer-symbolic", ref preset_group_button);
            preset_custom_btn = create_preset_button (_ ("Custom"), "emblem-system-symbolic", ref preset_group_button);

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
            refresh ();
        }

        private void apply_preset (Models.MangoHudPreset preset) {
            if (is_updating || preset == Models.MangoHudPreset.CUSTOM) return;

            is_updating = true;
            config.set_preset (preset);
            config.save ();
            is_updating = false;
            
            changed (); // Notify MangoHudBox to refresh other pages
        }

        public override void refresh () {
            var selected = (int) config.get_preset ();
            is_updating = true;
            preset_buttons[selected].active = true;
            is_updating = false;
        }
    }
}
