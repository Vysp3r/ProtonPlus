namespace ProtonPlus.Widgets.MangoHud {
    public class PerformancePage : Page {
        private Adw.SwitchRow fps_row;
        private Adw.SwitchRow fps_avg_row;
        private Adw.SwitchRow fps_limit_stats_row;
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
        private Gtk.ListBoxRow af_row;
        private Gtk.Scale af_scale;
        private Gtk.ListBoxRow lod_bias_row;
        private Gtk.Scale lod_bias_scale;

        public PerformancePage (Utils.MangoHudManager config) {
            base (config);

            fps_row = create_switch (_ ("Show FPS"), config.fps, (val) => { this.config.fps = val; });
            fps_avg_row = create_switch (_ ("FPS Average"), config.fps_avg, (val) => { this.config.fps_avg = val; });
            fps_limit_stats_row = create_switch (_ ("FPS Limit"), config.fps_limit_stats, (val) => { this.config.fps_limit_stats = val; });
            frametime_row = create_switch (_ ("Frame Time"), config.frametime, (val) => { this.config.frametime = val; });
            frame_count_row = create_switch (_ ("Count Frames"), config.frame_count, (val) => { this.config.frame_count = val; });
            vps_row = create_switch (_ ("VPS"), config.vps, (val) => { this.config.vps = val; });
            ftrace_row = create_switch (_ ("ftrace debug"), config.ftrace, (val) => { this.config.ftrace = val; });

            add_flow_group (this, _ ("Information"), {
                                                         fps_row, fps_avg_row, fps_limit_stats_row, frametime_row, frame_count_row, vps_row, ftrace_row
                                                     }, "heading");

            vsync_row = create_combo (_ ("Vulkan"), {_ ("Unset"), _ ("Adaptive"), _ ("Mailbox"), _ ("OFF"), _ ("ON")}, 0, null, (val) => {
                switch (val) {
                    case 0: this.config.vsync = ""; break;
                    case 1: this.config.vsync = "0"; break;
                    case 2: this.config.vsync = "1"; break;
                    case 3: this.config.vsync = "2"; break;
                    case 4: this.config.vsync = "3"; break;
                }
            });

            gl_vsync_row = create_combo (_ ("OpenGL"), {_ ("Unset"), _ ("Adaptive"), _ ("OFF"), _ ("ON")}, 0, null, (val) => {
                switch (val) {
                    case 0: this.config.gl_vsync = ""; break;
                    case 1: this.config.gl_vsync = "-1"; break;
                    case 2: this.config.gl_vsync = "0"; break;
                    case 3: this.config.gl_vsync = "1"; break;
                }
            });

            add_flow_group (this, _ ("VSYNC"), { vsync_row, gl_vsync_row }, "heading");

            fps_limit_row = create_entry (_ ("FPS Limit"), config.fps_limit, (val) => { this.config.fps_limit = val; });
            fps_limit_offset_row = create_entry (_ ("Offset"), config.fps_limit_offset.to_string (), (val) => {
                this.config.fps_limit_offset = val != "" ? int.parse (val) : 0;
            });

            var color_dialog = new Gtk.ColorDialog ();
            change_fps_limit_colors_row = create_switch (_ ("Change FPS Colors"), config.change_fps_limit_colors, (val) => {
                this.config.change_fps_limit_colors = val;
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

            fps_limit_method_row = create_combo (_ ("Method"), {"late", "early"}, 0, null, (val) => {
                switch (val) {
                    case 0: this.config.fps_limit_method = "late"; break;
                    case 1: this.config.fps_limit_method = "early"; break;
                }
            });

            toggle_fps_limit_row = create_combo (_ ("Limit Toggle Key"), {_ ("None"), "Shift_L+F1", "Shift_L+F2", "Shift_L+F3", "Shift_L+F4"}, 0, null, (val) => {
                switch (val) {
                    case 0: this.config.toggle_fps_limit = ""; break;
                    case 1: this.config.toggle_fps_limit = "Shift_L+F1"; break;
                    case 2: this.config.toggle_fps_limit = "Shift_L+F2"; break;
                    case 3: this.config.toggle_fps_limit = "Shift_L+F3"; break;
                    case 4: this.config.toggle_fps_limit = "Shift_L+F4"; break;
                }
            });

            add_flow_group (this, _ ("Limiters"), {
                                                      fps_limit_row, fps_limit_offset_row, change_fps_limit_colors_row, fps_limit_method_row, toggle_fps_limit_row
                                                  }, "heading");

            picmip_row = create_combo (_ ("Filtering"), {_ ("None"), _ ("Bicubic"), _ ("Trilinear"), _ ("Retro")}, 0, null, (val) => {
                switch (val) {
                    case 0: this.config.picmip = ""; break;
                    case 1: this.config.picmip = "0"; break;
                    case 2: this.config.picmip = "0"; break;
                    case 3: this.config.picmip = "-1"; break;
                }
            });

            af_row = create_scale (_ ("Anisotropic Filtering"), 0, 16, 1, out af_scale, (val) => { this.config.af = val; });
            lod_bias_row = create_scale (_ ("Mip-map LoD Bias"), -16, 16, 1, out lod_bias_scale, (val) => { this.config.lod_bias = val; });

            add_flow_group (this, _ ("Filters"), { picmip_row, af_row, lod_bias_row }, "heading");

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

            af_scale.set_value (config.af != "" ? double.parse (config.af) : 0);
            lod_bias_scale.set_value (config.lod_bias != "" ? double.parse (config.lod_bias) : 0);
            is_updating = false;
        }

        private void update_fps_limit_colors () {
            if (is_updating) return;
            Gdk.RGBA c1, c2, c3;
            fps_limit_color_1_btn.get ("rgba", out c1);
            fps_limit_color_2_btn.get ("rgba", out c2);
            fps_limit_color_3_btn.get ("rgba", out c3);
            config.fps_limit_colors = "%s,%s,%s".printf (rgba_to_hex (c1), rgba_to_hex (c2), rgba_to_hex (c3));
            changed ();
        }

        private void refresh_fps_limit_color_btns () {
            var fps_limit_colors = config.fps_limit_colors.split (",");
            if (fps_limit_colors.length == 3) {
                fps_limit_color_1_btn.rgba = hex_to_rgba (fps_limit_colors[0]);
                fps_limit_color_2_btn.rgba = hex_to_rgba (fps_limit_colors[1]);
                fps_limit_color_3_btn.rgba = hex_to_rgba (fps_limit_colors[2]);
            }
        }
    }
}
