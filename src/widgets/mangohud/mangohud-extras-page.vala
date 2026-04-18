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
            distro_row = create_switch (_ ("Distro info"), config.distro, (val) => { config.distro = val; });
            refresh_rate_row = create_switch (_ ("Refresh rate*"), config.refresh_rate, (val) => { config.refresh_rate = val; });
            resolution_row = create_switch (_ ("Resolution"), config.resolution, (val) => { config.resolution = val; });
            display_server_row = create_switch (_ ("Display Server"), config.display_server, (val) => { config.display_server = val; });
            time_row = create_switch (_ ("Time"), config.time, (val) => { config.time = val; });
            arch_row = create_switch (_ ("Arch"), config.arch, (val) => { config.arch = val; });

            var system_flow_box = create_flow_box ();
            system_flow_box.append (create_row_card (distro_row));
            system_flow_box.append (create_row_card (refresh_rate_row));
            system_flow_box.append (create_row_card (resolution_row));
            system_flow_box.append (create_row_card (display_server_row));
            system_flow_box.append (create_row_card (time_row));
            system_flow_box.append (create_row_card (arch_row));
            add_group_to_page (info_box, _ ("System"), system_flow_box, "caption");

            // Wine subsection
            wine_row = create_switch (_ ("Wine Ver"), config.wine, (val) => { config.wine = val; });
            wine_color_btn = create_color_button (color_dialog, config.wine_color, (val) => { config.wine_color = val; });
            wine_row.add_suffix (wine_color_btn);
            wine_row.bind_property ("active", wine_color_btn, "visible", BindingFlags.SYNC_CREATE);

            engine_version_row = create_switch (_ ("Engine Ver"), config.engine_version, (val) => { config.engine_version = val; });
            engine_color_btn = create_color_button (color_dialog, config.engine_color, (val) => { config.engine_color = val; });
            engine_version_row.add_suffix (engine_color_btn);
            engine_version_row.bind_property ("active", engine_color_btn, "visible", BindingFlags.SYNC_CREATE);

            engine_short_names_row = create_switch (_ ("Engine Short"), config.engine_short_names, (val) => { config.engine_short_names = val; });
            wine_sync_row = create_switch (_ ("Wine Sync"), config.wine_sync, (val) => { config.wine_sync = val; });
            dx_api_row = create_switch (_ ("DX API"), config.dx_api, (val) => { config.dx_api = val; });
            fex_stats_row = create_switch (_ ("FEX Stats"), config.fex_stats, (val) => { config.fex_stats = val; });

            var wine_flow_box = create_flow_box ();
            wine_flow_box.append (create_row_card (wine_row));
            wine_flow_box.append (create_row_card (engine_version_row));
            wine_flow_box.append (create_row_card (engine_short_names_row));
            wine_flow_box.append (create_row_card (wine_sync_row));
            wine_flow_box.append (create_row_card (dx_api_row));
            wine_flow_box.append (create_row_card (fex_stats_row));
            add_group_to_page (info_box, _ ("Wine"), wine_flow_box, "caption");

            // Options subsection
            hud_version_row = create_switch (_ ("HUD Version"), config.hud_version, (val) => { config.hud_version = val; });
            gamemode_row = create_switch (_ ("GameMode"), config.gamemode, (val) => { config.gamemode = val; });
            vkbasalt_row = create_switch (_ ("vkBasalt"), config.vkbasalt, (val) => { config.vkbasalt = val; });
            fcat_row = create_switch (_ ("FCAT"), config.fcat, (val) => { config.fcat = val; });
            fsr_row = create_switch (_ ("FSR*"), config.fsr, (val) => { config.fsr = val; });
            hdr_row = create_switch (_ ("HDR*"), config.hdr, (val) => { config.hdr = val; });

            var options_flow_box = create_flow_box ();
            options_flow_box.append (create_row_card (hud_version_row));
            options_flow_box.append (create_row_card (gamemode_row));
            options_flow_box.append (create_row_card (vkbasalt_row));
            options_flow_box.append (create_row_card (fcat_row));
            options_flow_box.append (create_row_card (fsr_row));
            options_flow_box.append (create_row_card (hdr_row));
            add_group_to_page (info_box, _ ("Options"), options_flow_box, "caption");

            // Battery subsection
            battery_row = create_switch (_ ("Percentage"), config.battery, (val) => { config.battery = val; });
            battery_color_btn = create_color_button (color_dialog, config.battery_color, (val) => { config.battery_color = val; });
            battery_row.add_suffix (battery_color_btn);
            battery_row.bind_property ("active", battery_color_btn, "visible", BindingFlags.SYNC_CREATE);

            battery_wattage_row = create_switch (_ ("Wattage"), config.battery_wattage, (val) => { config.battery_wattage = val; });
            battery_time_row = create_switch (_ ("Time remain"), config.battery_time, (val) => { config.battery_time = val; });
            device_battery_row = create_switch (_ ("Devices"), config.device_battery, (val) => { config.device_battery = val; });

            var battery_flow_box = create_flow_box ();
            battery_flow_box.append (create_row_card (battery_row));
            battery_flow_box.append (create_row_card (battery_wattage_row));
            battery_flow_box.append (create_row_card (battery_time_row));
            battery_flow_box.append (create_row_card (device_battery_row));
            add_group_to_page (info_box, _ ("Battery"), battery_flow_box, "caption");

            // Others subsection
            media_player_row = create_switch (_ ("Media Info"), config.media_player, (val) => { config.media_player = val; });
            media_player_color_btn = create_color_button (color_dialog, config.media_player_color, (val) => { config.media_player_color = val; });
            media_player_row.add_suffix (media_player_color_btn);
            media_player_row.bind_property ("active", media_player_color_btn, "visible", BindingFlags.SYNC_CREATE);

            network_row = new Adw.EntryRow () {
                title = _ ("Network"),
                text = config.network
            };
            network_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.network = network_row.text;
                config.save ();
            });
            fahrenheit_row = create_switch (_ ("Fahrenheit"), config.fahrenheit, (val) => { config.fahrenheit = val; });
            custom_text_row = new Adw.EntryRow () {
                title = _ ("Custom command"),
                text = config.custom_text
            };
            custom_text_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.custom_text = custom_text_row.text;
                config.save ();
            });

            var others_flow_box = create_flow_box ();
            others_flow_box.append (create_row_card (media_player_row));
            others_flow_box.append (create_row_card (network_row));
            others_flow_box.append (create_row_card (fahrenheit_row));
            others_flow_box.append (create_row_card (custom_text_row));
            add_group_to_page (info_box, _ ("Others"), others_flow_box, "caption");

            this.append (info_box);

            // Logging section
            var logging_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var logging_label = new Gtk.Label (_ ("Logging")) {
                halign = Gtk.Align.START,
                margin_start = 12
            };
            logging_label.add_css_class ("heading");
            logging_box.append (logging_label);

            autostart_log_row = create_scale (_ ("Duration"), 0, 200, 1, out log_duration_scale, (val) => { config.log_duration = val; });
            log_duration_row = create_scale (_ ("Autostart"), 0, 30, 1, out autostart_log_scale, (val) => { config.autostart_log = val; });
            log_interval_row = create_scale (_ ("Interval"), 0, 500, 10, out log_interval_scale, (val) => { config.log_interval = val; });
            toggle_logging_row = new Adw.ComboRow () {
                title = _ ("Toggle key"),
                icon_name = "preferences-desktop-keyboard-shortcuts-symbolic",
                model = new Gtk.StringList ({"Shift_L+F2", "Shift_L+F3", "Shift_L+F4", "Shift_L+F5", _ ("None")})
            };
            refresh_toggle_logging_row ();
            toggle_logging_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (toggle_logging_row.selected) {
                    case 0: config.toggle_logging = "Shift_L+F2"; break;
                    case 1: config.toggle_logging = "Shift_L+F3"; break;
                    case 2: config.toggle_logging = "Shift_L+F4"; break;
                    case 3: config.toggle_logging = "Shift_L+F5"; break;
                    case 4: config.toggle_logging = ""; break;
                }
                config.save ();
            });
            output_folder_row = new Adw.EntryRow () {
                title = _ ("Output Folder"),
                text = config.output_folder
            };
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
            output_folder_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.output_folder = output_folder_row.text;
                config.save ();
            });

            upload_log_row = create_switch (_ ("Autoupload results"), config.upload_log, (val) => { config.upload_log = val; });
            log_versioning_row = create_switch (_ ("Log Versioning"), config.log_versioning, (val) => { config.log_versioning = val; });

            var logging_flow_box = create_flow_box ();
            logging_flow_box.append (create_row_card (autostart_log_row));
            logging_flow_box.append (create_row_card (log_duration_row));
            logging_flow_box.append (create_row_card (log_interval_row));
            logging_flow_box.append (create_row_card (toggle_logging_row));
            logging_flow_box.append (create_row_card (output_folder_row));
            logging_flow_box.append (create_row_card (upload_log_row));
            logging_flow_box.append (create_row_card (log_versioning_row));

            add_group_to_page (logging_box, null, logging_flow_box, "caption");

            this.append (logging_box);
        }

        private delegate void SetValueFunc (bool val);
        private delegate void SetValueFuncStr (string val);

        private Gtk.ListBoxRow create_scale (string title, double min, double max, double step, out Gtk.Scale scale_out, SetValueFuncStr set_value) {
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
                if (is_updating) return;
                set_value ("%.0f".printf (scale.get_value ()));
                config.save ();
            });
            box.append (scale);
            row.set_child (box);
            scale_out = scale;
            return row;
        }

        private Adw.SwitchRow create_switch (string title, bool initial_value, SetValueFunc set_value) {
            var row = new Adw.SwitchRow () {
                title = title,
                active = initial_value
            };
            row.notify["active"].connect (() => {
                if (is_updating) return;
                set_value (row.active);
                config.save ();
                changed ();
            });
            return row;
        }

        private Gtk.ColorDialogButton create_color_button (Gtk.ColorDialog dialog, string initial_color, SetValueFuncStr set_color) {
            var btn = new Gtk.ColorDialogButton (dialog);
            btn.set_valign (Gtk.Align.CENTER);
            var rgba = Gdk.RGBA ();
            if (initial_color != "") {
                rgba.parse ("#" + initial_color);
            } else {
                rgba.parse ("#ffffff");
            }
            btn.rgba = rgba;
            btn.notify["rgba"].connect (() => {
                if (is_updating) return;
                var btn_rgba = btn.get_rgba ();
                set_color ("%02x%02x%02x".printf ((uint) (btn_rgba.red * 255), (uint) (btn_rgba.green * 255), (uint) (btn_rgba.blue * 255)));
                config.save ();
            });
            return btn;
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

            var wine_rgba = Gdk.RGBA ();
            if (config.wine_color != "") {
                wine_rgba.parse ("#" + config.wine_color);
            } else {
                wine_rgba.parse ("#ffffff");
            }
            wine_color_btn.rgba = wine_rgba;

            var engine_rgba = Gdk.RGBA ();
            if (config.engine_color != "") {
                engine_rgba.parse ("#" + config.engine_color);
            } else {
                engine_rgba.parse ("#ffffff");
            }
            engine_color_btn.rgba = engine_rgba;

            var battery_rgba = Gdk.RGBA ();
            if (config.battery_color != "") {
                battery_rgba.parse ("#" + config.battery_color);
            } else {
                battery_rgba.parse ("#ffffff");
            }
            battery_color_btn.rgba = battery_rgba;

            var media_player_rgba = Gdk.RGBA ();
            if (config.media_player_color != "") {
                media_player_rgba.parse ("#" + config.media_player_color);
            } else {
                media_player_rgba.parse ("#ffffff");
            }
            media_player_color_btn.rgba = media_player_rgba;

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
