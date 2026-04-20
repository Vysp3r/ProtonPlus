namespace ProtonPlus.Widgets {
    public class MangoHudExtrasPage : MangoHudPage {
        // System rows
        private Adw.SwitchRow distro_row;
        private Adw.SwitchRow refresh_rate_row;
        private Adw.SwitchRow resolution_row;
        private Adw.SwitchRow display_server_row;
        private Adw.SwitchRow arch_row;
        private Adw.SwitchRow wine_row;
        private Adw.SwitchRow engine_version_row;
        private Adw.SwitchRow engine_short_names_row;
        private Adw.SwitchRow wine_sync_row;
        private Adw.SwitchRow dx_api_row;
        private Adw.SwitchRow fex_stats_row;
        private Adw.SwitchRow hud_version_row;
        private Adw.SwitchRow gamemode_row;
        private Adw.SwitchRow vkbasalt_row;
        private Adw.SwitchRow fcat_row;
        private Adw.SwitchRow fsr_row;
        private Adw.SwitchRow hdr_row;
        private Adw.SwitchRow battery_row;
        private Adw.SwitchRow battery_wattage_row;
        private Adw.SwitchRow battery_time_row;
        private Adw.SwitchRow device_battery_row;
        private Adw.SwitchRow media_player_row;

        private Gtk.ColorDialogButton wine_color_btn;
        private Gtk.ColorDialogButton engine_color_btn;
        private Gtk.ColorDialogButton battery_color_btn;
        private Gtk.ColorDialogButton media_player_color_btn;

        private Adw.EntryRow network_row;
        private Adw.SwitchRow fahrenheit_row;

        // Miscellaneous rows
        private Adw.SwitchRow time_row;
        private Adw.EntryRow custom_text_row;

        // Logging rows
        private Gtk.ListBoxRow autostart_log_row;
        private Gtk.Scale autostart_log_scale;
        private Gtk.ListBoxRow log_duration_row;
        private Gtk.Scale log_duration_scale;
        private Gtk.ListBoxRow log_interval_row;
        private Gtk.Scale log_interval_scale;
        private Adw.ComboRow toggle_logging_row;
        private Adw.EntryRow output_folder_row;

        private Adw.SwitchRow upload_log_row;
        private Adw.SwitchRow log_versioning_row;

        public MangoHudExtrasPage (Models.MangoHudConfig config) {
            base (config);

            var color_dialog = new Gtk.ColorDialog ();

            // System Information section
            var info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var info_label = new Gtk.Label (_ ("System Information")) {
                halign = Gtk.Align.START,
                margin_start = 12
            };
            info_label.add_css_class ("heading");
            info_box.append (info_label);

            // System subsection
            distro_row = create_switch (_ ("Distro info"), config.distro, (val) => { this.config.distro = val; });
            refresh_rate_row = create_switch (_ ("Refresh rate*"), config.refresh_rate, (val) => { this.config.refresh_rate = val; });
            resolution_row = create_switch (_ ("Resolution"), config.resolution, (val) => { this.config.resolution = val; });
            display_server_row = create_switch (_ ("Display Server"), config.display_server, (val) => { this.config.display_server = val; });
            time_row = create_switch (_ ("Time"), config.time, (val) => { this.config.time = val; });
            arch_row = create_switch (_ ("Arch"), config.arch, (val) => { this.config.arch = val; });

            add_flow_group (info_box, _ ("System"), {
                distro_row, refresh_rate_row, resolution_row, display_server_row, time_row, arch_row
            });

            // Wine subsection
            wine_row = create_switch (_ ("Wine Ver"), config.wine, (val) => { this.config.wine = val; });
            wine_color_btn = create_color_button (color_dialog, config.wine_color, (val) => { this.config.wine_color = val; });
            wine_row.add_suffix (wine_color_btn);
            wine_row.bind_property ("active", wine_color_btn, "visible", BindingFlags.SYNC_CREATE);

            engine_version_row = create_switch (_ ("Engine Ver"), config.engine_version, (val) => { this.config.engine_version = val; });
            engine_color_btn = create_color_button (color_dialog, config.engine_color, (val) => { this.config.engine_color = val; });
            engine_version_row.add_suffix (engine_color_btn);
            engine_version_row.bind_property ("active", engine_color_btn, "visible", BindingFlags.SYNC_CREATE);

            engine_short_names_row = create_switch (_ ("Engine Short"), config.engine_short_names, (val) => { this.config.engine_short_names = val; });
            wine_sync_row = create_switch (_ ("Wine Sync"), config.wine_sync, (val) => { this.config.wine_sync = val; });
            dx_api_row = create_switch (_ ("DX API"), config.dx_api, (val) => { this.config.dx_api = val; });
            fex_stats_row = create_switch (_ ("FEX Stats"), config.fex_stats, (val) => { this.config.fex_stats = val; });

            add_flow_group (info_box, _ ("Wine"), {
                wine_row, engine_version_row, engine_short_names_row, wine_sync_row, dx_api_row, fex_stats_row
            });

            // Options subsection
            hud_version_row = create_switch (_ ("HUD Version"), config.hud_version, (val) => { this.config.hud_version = val; });
            gamemode_row = create_switch (_ ("GameMode"), config.gamemode, (val) => { this.config.gamemode = val; });
            vkbasalt_row = create_switch (_ ("vkBasalt"), config.vkbasalt, (val) => { this.config.vkbasalt = val; });
            fcat_row = create_switch (_ ("FCAT"), config.fcat, (val) => { this.config.fcat = val; });
            fsr_row = create_switch (_ ("FSR*"), config.fsr, (val) => { this.config.fsr = val; });
            hdr_row = create_switch (_ ("HDR*"), config.hdr, (val) => { this.config.hdr = val; });

            add_flow_group (info_box, _ ("Options"), {
                hud_version_row, gamemode_row, vkbasalt_row, fcat_row, fsr_row, hdr_row
            });

            // Battery subsection
            battery_row = create_switch (_ ("Percentage"), config.battery, (val) => { this.config.battery = val; });
            battery_color_btn = create_color_button (color_dialog, config.battery_color, (val) => { this.config.battery_color = val; });
            battery_row.add_suffix (battery_color_btn);
            battery_row.bind_property ("active", battery_color_btn, "visible", BindingFlags.SYNC_CREATE);

            battery_wattage_row = create_switch (_ ("Wattage"), config.battery_wattage, (val) => { this.config.battery_wattage = val; });
            battery_time_row = create_switch (_ ("Time remain"), config.battery_time, (val) => { this.config.battery_time = val; });
            device_battery_row = create_switch (_ ("Devices"), config.device_battery, (val) => { this.config.device_battery = val; });

            add_flow_group (info_box, _ ("Battery"), {
                battery_row, battery_wattage_row, battery_time_row, device_battery_row
            });

            // Others subsection
            media_player_row = create_switch (_ ("Media Info"), config.media_player, (val) => { this.config.media_player = val; });
            media_player_color_btn = create_color_button (color_dialog, config.media_player_color, (val) => { this.config.media_player_color = val; });
            media_player_row.add_suffix (media_player_color_btn);
            media_player_row.bind_property ("active", media_player_color_btn, "visible", BindingFlags.SYNC_CREATE);

            network_row = create_entry (_ ("Network"), config.network, (val) => { this.config.network = val; });
            fahrenheit_row = create_switch (_ ("Fahrenheit"), config.fahrenheit, (val) => { this.config.fahrenheit = val; });
            custom_text_row = create_entry (_ ("Custom command"), config.custom_text, (val) => { this.config.custom_text = val; });

            add_flow_group (info_box, _ ("Others"), {
                media_player_row, network_row, fahrenheit_row, custom_text_row
            });

            this.append (info_box);

            // Logging section
            var logging_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var logging_label = new Gtk.Label (_ ("Logging")) {
                halign = Gtk.Align.START,
                margin_start = 12
            };
            logging_label.add_css_class ("heading");
            logging_box.append (logging_label);

            autostart_log_row = create_scale (_ ("Duration"), 0, 200, 1, out log_duration_scale, (val) => { this.config.log_duration = val; });
            log_duration_row = create_scale (_ ("Autostart"), 0, 30, 1, out autostart_log_scale, (val) => { this.config.autostart_log = val; });
            log_interval_row = create_scale (_ ("Interval"), 0, 500, 1, out log_interval_scale, (val) => { this.config.log_interval = val; });
            toggle_logging_row = create_combo (_ ("Toggle key"), {"Shift_L+F2", "Shift_L+F3", "Shift_L+F4", "Shift_L+F5", _ ("None")}, 0, "preferences-desktop-keyboard-shortcuts-symbolic", (val) => {
                switch (val) {
                    case 0: this.config.toggle_logging = "Shift_L+F2"; break;
                    case 1: this.config.toggle_logging = "Shift_L+F3"; break;
                    case 2: this.config.toggle_logging = "Shift_L+F4"; break;
                    case 3: this.config.toggle_logging = "Shift_L+F5"; break;
                    case 4: this.config.toggle_logging = ""; break;
                }
            });
            refresh_toggle_logging_row ();

            output_folder_row = create_entry (_ ("Output Folder"), config.output_folder, (val) => { this.config.output_folder = val; });
            var output_folder_btn = new Gtk.Button.from_icon_name ("folder-open-symbolic");
            output_folder_btn.set_valign (Gtk.Align.CENTER);
            output_folder_row.add_suffix (output_folder_btn);
            output_folder_btn.clicked.connect (() => {
                var folder_dialog = new Gtk.FileDialog () {
                    title = _ ("Select Output Folder")
                };
                folder_dialog.select_folder.begin (null, null, (obj, res) => {
                    try {
                        var file = folder_dialog.select_folder.end (res);
                        output_folder_row.text = file.get_path ();
                    } catch (Error e) {
                        warning (e.message);
                    }
                });
            });

            upload_log_row = create_switch (_ ("Autoupload Results"), config.upload_log, (val) => { this.config.upload_log = val; });
            log_versioning_row = create_switch (_ ("Log Versioning"), config.log_versioning, (val) => { this.config.log_versioning = val; });

            add_flow_group (logging_box, null, {
                autostart_log_row, log_duration_row, log_interval_row, toggle_logging_row, output_folder_row, upload_log_row, log_versioning_row
            });

            this.append (logging_box);
        }


        private void refresh_toggle_logging_row () {
            int toggle_index = 4;
            switch (config.toggle_logging) {
                case "Shift_L+F2": toggle_index = 0; break;
                case "Shift_L+F3": toggle_index = 1; break;
                case "Shift_L+F4": toggle_index = 2; break;
                case "Shift_L+F5": toggle_index = 3; break;
                case "": toggle_index = 4; break;
            }
            toggle_logging_row.selected = toggle_index;
        }

        public override void refresh () {
            is_updating = true;
            distro_row.active = config.distro;
            refresh_rate_row.active = config.refresh_rate;
            resolution_row.active = config.resolution;
            display_server_row.active = config.display_server;
            arch_row.active = config.arch;
            wine_row.active = config.wine;
            engine_version_row.active = config.engine_version;
            engine_short_names_row.active = config.engine_short_names;
            wine_sync_row.active = config.wine_sync;
            dx_api_row.active = config.dx_api;
            fex_stats_row.active = config.fex_stats;
            hud_version_row.active = config.hud_version;
            gamemode_row.active = config.gamemode;
            vkbasalt_row.active = config.vkbasalt;
            fcat_row.active = config.fcat;
            fsr_row.active = config.fsr;
            hdr_row.active = config.hdr;
            battery_row.active = config.battery;
            battery_wattage_row.active = config.battery_wattage;
            battery_time_row.active = config.battery_time;
            device_battery_row.active = config.device_battery;
            media_player_row.active = config.media_player;

            wine_color_btn.rgba = hex_to_rgba (config.wine_color);

            engine_color_btn.rgba = hex_to_rgba (config.engine_color);

            battery_color_btn.rgba = hex_to_rgba (config.battery_color);

            media_player_color_btn.rgba = hex_to_rgba (config.media_player_color);

            network_row.text = config.network;
            fahrenheit_row.active = config.fahrenheit;

            time_row.active = config.time;
            custom_text_row.text = config.custom_text;

            autostart_log_scale.set_value (config.autostart_log != "" ? double.parse (config.autostart_log) : 0);
            log_duration_scale.set_value (config.log_duration != "" ? double.parse (config.log_duration) : 0);
            log_interval_scale.set_value (config.log_interval != "" ? double.parse (config.log_interval) : 0);
            refresh_toggle_logging_row ();
            output_folder_row.text = config.output_folder;
            upload_log_row.active = config.upload_log;
            log_versioning_row.active = config.log_versioning;
            is_updating = false;
        }
    }
}
