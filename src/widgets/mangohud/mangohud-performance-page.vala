namespace ProtonPlus.Widgets {
    public class MangoHudPerformancePage : MangoHudPage {
        private Adw.SwitchRow fps_row;
        private Adw.SwitchRow fps_avg_row;
        private Adw.SwitchRow fps_limit_stats_row;
        private Adw.SwitchRow fps_1_low_row;
        private Adw.SwitchRow frametime_row;
        private Adw.SwitchRow frame_count_row;
        private Adw.SwitchRow vps_row;
        private Adw.SwitchRow ftrace_row;

        private Adw.ComboRow vsync_row;
        private Adw.ComboRow gl_vsync_row;

        private Adw.EntryRow fps_limit_row;
        private Adw.EntryRow fps_limit_offset_row;
        private Adw.SwitchRow change_fps_limit_colors_row;
        private Gtk.ColorDialogButton fps_limit_color_1_btn;
        private Gtk.ColorDialogButton fps_limit_color_2_btn;
        private Gtk.ColorDialogButton fps_limit_color_3_btn;
        private Adw.ComboRow fps_limit_method_row;
        private Adw.ComboRow toggle_fps_limit_row;

        private Adw.ComboRow picmip_row;
        private Adw.ComboRow af_row;
        private Adw.ComboRow lod_bias_row;

        public MangoHudPerformancePage (Models.MangoHudConfig config) {
            base (config);

            var info_flow_box = create_flow_box ();
            var vsync_flow_box = create_flow_box ();
            var limiters_flow_box = create_flow_box ();
            var filters_flow_box = create_flow_box ();

            fps_row = new Adw.SwitchRow () {
                title = _ ("Show FPS"),
                active = config.fps
            };
            fps_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.fps = fps_row.active;
                config.save ();
                changed ();
            });
            info_flow_box.append (create_row_card (fps_row));

            fps_avg_row = new Adw.SwitchRow () {
                title = _ ("FPS Average"),
                active = config.fps_avg
            };
            fps_avg_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.fps_avg = fps_avg_row.active;
                config.save ();
            });
            info_flow_box.append (create_row_card (fps_avg_row));

            fps_limit_stats_row = new Adw.SwitchRow () {
                title = _ ("FPS Limit"),
                active = config.fps_limit_stats
            };
            fps_limit_stats_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.fps_limit_stats = fps_limit_stats_row.active;
                config.save ();
            });
            info_flow_box.append (create_row_card (fps_limit_stats_row));

            frametime_row = new Adw.SwitchRow () {
                title = _ ("Frame Time"),
                active = config.frametime
            };
            frametime_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.frametime = frametime_row.active;
                config.save ();
                changed ();
            });
            info_flow_box.append (create_row_card (frametime_row));

            frame_count_row = new Adw.SwitchRow () {
                title = _ ("Count Frames"),
                active = config.frame_count
            };
            frame_count_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.frame_count = frame_count_row.active;
                config.save ();
            });
            info_flow_box.append (create_row_card (frame_count_row));

            vps_row = new Adw.SwitchRow () {
                title = _ ("VPS"),
                active = config.vps
            };
            vps_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.vps = vps_row.active;
                config.save ();
            });
            info_flow_box.append (create_row_card (vps_row));

            ftrace_row = new Adw.SwitchRow () {
                title = _ ("ftrace debug"),
                active = config.ftrace
            };
            ftrace_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.ftrace = ftrace_row.active;
                config.save ();
            });
            info_flow_box.append (create_row_card (ftrace_row));

            vsync_row = new Adw.ComboRow () {
                title = _ ("Vulkan VSYNC"),
                model = new Gtk.StringList ({_ ("Unset"), _ ("Adaptive"), _ ("Mailbox"), _ ("OFF"), _ ("ON")}),
            };
            vsync_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (vsync_row.selected) {
                    case 0: config.vsync = ""; break;
                    case 1: config.vsync = "0"; break;
                    case 2: config.vsync = "1"; break;
                    case 3: config.vsync = "2"; break;
                    case 4: config.vsync = "3"; break;
                }
                config.save ();
            });
            vsync_flow_box.append (create_row_card (vsync_row));

            gl_vsync_row = new Adw.ComboRow () {
                title = _ ("OpenGL VSYNC"),
                model = new Gtk.StringList ({_ ("Unset"), _ ("Adaptive"), _ ("OFF"), _ ("ON")}),
            };
            gl_vsync_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (gl_vsync_row.selected) {
                    case 0: config.gl_vsync = ""; break;
                    case 1: config.gl_vsync = "-1"; break;
                    case 2: config.gl_vsync = "0"; break;
                    case 3: config.gl_vsync = "1"; break;
                }
                config.save ();
            });
            vsync_flow_box.append (create_row_card (gl_vsync_row));

            fps_limit_row = new Adw.EntryRow () {
                title = _ ("FPS Limit"),
                text = config.fps_limit
            };
            fps_limit_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.fps_limit = fps_limit_row.text;
                config.save ();
            });
            limiters_flow_box.append (create_row_card (fps_limit_row));

            fps_limit_offset_row = new Adw.EntryRow () {
                title = _ ("Offset"),
                text = config.fps_limit_offset.to_string ()
            };
            fps_limit_offset_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.fps_limit_offset = fps_limit_offset_row.text != "" ? int.parse (fps_limit_offset_row.text) : 0;
                config.save ();
            });
            limiters_flow_box.append (create_row_card (fps_limit_offset_row));

            var color_dialog = new Gtk.ColorDialog ();
            change_fps_limit_colors_row = new Adw.SwitchRow () {
                title = _ ("Change FPS Colors"),
                active = config.change_fps_limit_colors
            };
            change_fps_limit_colors_row.notify["active"].connect (() => {
                if (is_updating) return;
                config.change_fps_limit_colors = change_fps_limit_colors_row.active;
                config.save ();
            });

            fps_limit_color_1_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            fps_limit_color_2_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            fps_limit_color_3_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            var fps_limit_color_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            fps_limit_color_box.append (fps_limit_color_1_btn);
            fps_limit_color_box.append (fps_limit_color_2_btn);
            fps_limit_color_box.append (fps_limit_color_3_btn);
            change_fps_limit_colors_row.add_suffix (fps_limit_color_box);
            change_fps_limit_colors_row.bind_property ("active", fps_limit_color_box, "visible", BindingFlags.SYNC_CREATE);
            refresh_fps_limit_color_btns ();

            fps_limit_color_1_btn.notify["rgba"].connect (update_fps_limit_colors);
            fps_limit_color_2_btn.notify["rgba"].connect (update_fps_limit_colors);
            fps_limit_color_3_btn.notify["rgba"].connect (update_fps_limit_colors);

            limiters_flow_box.append (create_row_card (change_fps_limit_colors_row));

            fps_limit_method_row = new Adw.ComboRow () {
                title = _ ("Method"),
                model = new Gtk.StringList ({"late", "early"}),
            };
            fps_limit_method_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (fps_limit_method_row.selected) {
                    case 0: config.fps_limit_method = "late"; break;
                    case 1: config.fps_limit_method = "early"; break;
                }
                config.save ();
            });
            limiters_flow_box.append (create_row_card (fps_limit_method_row));

            toggle_fps_limit_row = new Adw.ComboRow () {
                title = _ ("Limit Toggle Key"),
                model = new Gtk.StringList ({_ ("None"), "Shift_L+F1", "Shift_L+F2", "Shift_L+F3", "Shift_L+F4"}),
            };
            toggle_fps_limit_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (toggle_fps_limit_row.selected) {
                    case 0: config.toggle_fps_limit = ""; break;
                    case 1: config.toggle_fps_limit = "Shift_L+F1"; break;
                    case 2: config.toggle_fps_limit = "Shift_L+F2"; break;
                    case 3: config.toggle_fps_limit = "Shift_L+F3"; break;
                    case 4: config.toggle_fps_limit = "Shift_L+F4"; break;
                }
                config.save ();
            });
            limiters_flow_box.append (create_row_card (toggle_fps_limit_row));

            picmip_row = new Adw.ComboRow () {
                title = _ ("Filtering"),
                model = new Gtk.StringList ({_ ("None"), _ ("Bicubic"), _ ("Trilinear"), _ ("Retro")}),
            };
            picmip_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (picmip_row.selected) {
                    case 0: config.picmip = ""; break;
                    case 1: config.picmip = "0"; break;
                    case 2: config.picmip = "0"; break;
                    case 3: config.picmip = "-1"; break;
                }
                config.save ();
            });
            filters_flow_box.append (create_row_card (picmip_row));

            af_row = new Adw.ComboRow () {
                title = _ ("Anisotropic Filtering"),
                model = new Gtk.StringList ({"0", "2", "4", "8", "16"}),
            };
            af_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (af_row.selected) {
                    case 0: config.af = "0"; break;
                    case 1: config.af = "2"; break;
                    case 2: config.af = "4"; break;
                    case 3: config.af = "8"; break;
                    case 4: config.af = "16"; break;
                }
                config.save ();
            });
            filters_flow_box.append (create_row_card (af_row));

            lod_bias_row = new Adw.ComboRow () {
                title = _ ("Mip-map LoD Bias"),
                model = new Gtk.StringList ({"-16", "-8", "-4", "-2", "0", "2", "4", "8", "16"}),
            };
            lod_bias_row.notify["selected"].connect (() => {
                if (is_updating) return;
                switch (lod_bias_row.selected) {
                    case 0: config.lod_bias = "-16"; break;
                    case 1: config.lod_bias = "-8"; break;
                    case 2: config.lod_bias = "-4"; break;
                    case 3: config.lod_bias = "-2"; break;
                    case 4: config.lod_bias = "0"; break;
                    case 5: config.lod_bias = "2"; break;
                    case 6: config.lod_bias = "4"; break;
                    case 7: config.lod_bias = "8"; break;
                    case 8: config.lod_bias = "16"; break;
                }
                config.save ();
            });
            filters_flow_box.append (create_row_card (lod_bias_row));

            add_group_to_page (this, _ ("Information"), info_flow_box);
            add_group_to_page (this, _ ("VSYNC"), vsync_flow_box);
            add_group_to_page (this, _ ("Limiters"), limiters_flow_box);
            add_group_to_page (this, _ ("Filters"), filters_flow_box);
            refresh ();
        }

        public override void refresh () {
            is_updating = true;
            fps_row.active = config.fps;
            fps_avg_row.active = config.fps_avg;
            fps_limit_stats_row.active = config.fps_limit_stats;
            frametime_row.active = config.frametime;
            frame_count_row.active = config.frame_count;
            vps_row.active = config.vps;
            ftrace_row.active = config.ftrace;

            int vsync_index = 0;
            switch (config.vsync) {
                case "": vsync_index = 0; break;
                case "0": vsync_index = 1; break;
                case "1": vsync_index = 2; break;
                case "2": vsync_index = 3; break;
                case "3": vsync_index = 4; break;
            }
            vsync_row.selected = vsync_index;

            int gl_vsync_index = 0;
            switch (config.gl_vsync) {
                case "": gl_vsync_index = 0; break;
                case "-1": gl_vsync_index = 1; break;
                case "0": gl_vsync_index = 2; break;
                case "1": gl_vsync_index = 3; break;
            }
            gl_vsync_row.selected = gl_vsync_index;

            fps_limit_row.text = config.fps_limit;
            fps_limit_offset_row.text = config.fps_limit_offset.to_string ();
            change_fps_limit_colors_row.active = config.change_fps_limit_colors;
            refresh_fps_limit_color_btns ();

            int fps_limit_method_index = 0;
            switch (config.fps_limit_method) {
                case "late": fps_limit_method_index = 0; break;
                case "early": fps_limit_method_index = 1; break;
            }
            fps_limit_method_row.selected = fps_limit_method_index;

            int toggle_fps_limit_index = 0;
            switch (config.toggle_fps_limit) {
                case "": toggle_fps_limit_index = 0; break;
                case "Shift_L+F1": toggle_fps_limit_index = 1; break;
                case "Shift_L+F2": toggle_fps_limit_index = 2; break;
                case "Shift_L+F3": toggle_fps_limit_index = 3; break;
                case "Shift_L+F4": toggle_fps_limit_index = 4; break;
            }
            toggle_fps_limit_row.selected = toggle_fps_limit_index;

            if (config.picmip == "") picmip_row.selected = 0;
            else if (config.picmip == "-1") picmip_row.selected = 3;
            else picmip_row.selected = 1;

            int af_index = 0;
            switch (config.af) {
                case "0": af_index = 0; break;
                case "2": af_index = 1; break;
                case "4": af_index = 2; break;
                case "8": af_index = 3; break;
                case "16": af_index = 4; break;
            }
            af_row.selected = af_index;

            int lod_bias_index = 0;
            switch (config.lod_bias) {
                case "-16": lod_bias_index = 0; break;
                case "-8": lod_bias_index = 1; break;
                case "-4": lod_bias_index = 2; break;
                case "-2": lod_bias_index = 3; break;
                case "0": lod_bias_index = 4; break;
                case "2": lod_bias_index = 5; break;
                case "4": lod_bias_index = 6; break;
                case "8": lod_bias_index = 7; break;
                case "16": lod_bias_index = 8; break;
            }
            lod_bias_row.selected = lod_bias_index;
            is_updating = false;
        }

        private void update_fps_limit_colors () {
            if (is_updating) return;
            var c1 = fps_limit_color_1_btn.get_rgba ();
            var c2 = fps_limit_color_2_btn.get_rgba ();
            var c3 = fps_limit_color_3_btn.get_rgba ();
            config.fps_limit_colors = "%02x%02x%02x,%02x%02x%02x,%02x%02x%02x".printf (
                (uint) (c1.red * 255), (uint) (c1.green * 255), (uint) (c1.blue * 255),
                (uint) (c2.red * 255), (uint) (c2.green * 255), (uint) (c2.blue * 255),
                (uint) (c3.red * 255), (uint) (c3.green * 255), (uint) (c3.blue * 255)
            );
            config.save ();
        }

        private void refresh_fps_limit_color_btns () {
            var fps_limit_colors = config.fps_limit_colors.split (",");
            if (fps_limit_colors.length == 3) {
                var rgba1 = Gdk.RGBA (); rgba1.parse ("#" + fps_limit_colors[0]); fps_limit_color_1_btn.rgba = rgba1;
                var rgba2 = Gdk.RGBA (); rgba2.parse ("#" + fps_limit_colors[1]); fps_limit_color_2_btn.rgba = rgba2;
                var rgba3 = Gdk.RGBA (); rgba3.parse ("#" + fps_limit_colors[2]); fps_limit_color_3_btn.rgba = rgba3;
            }
        }
    }
}
