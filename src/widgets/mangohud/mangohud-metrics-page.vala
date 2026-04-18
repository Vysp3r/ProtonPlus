namespace ProtonPlus.Widgets {
    public class MangoHudMetricsPage : MangoHudPage {
        // GPU rows
        private Adw.EntryRow gpu_custom_name_row;
        private Gtk.ColorDialogButton gpu_color_btn;
        private Adw.SwitchRow gpu_stats_row;
        private Adw.SwitchRow gpu_load_color_row;
        private Gtk.ColorDialogButton gpu_load_color_1_btn;
        private Gtk.ColorDialogButton gpu_load_color_2_btn;
        private Gtk.ColorDialogButton gpu_load_color_3_btn;
        private Adw.SwitchRow vram_row;
        private Adw.SwitchRow gpu_core_clock_row;
        private Adw.SwitchRow gpu_mem_clock_row;
        private Adw.SwitchRow gpu_temp_row;
        private Adw.SwitchRow gpu_mem_temp_row;
        private Adw.SwitchRow gpu_junction_temp_row;
        private Adw.SwitchRow gpu_fan_row;
        private Adw.SwitchRow gpu_power_row;
        private Adw.SwitchRow gpu_voltage_row;
        private Adw.SwitchRow throttling_status_row;
        private Adw.SwitchRow throttling_graph_row;
        private Adw.SwitchRow gpu_efficiency_row;
        private Adw.SwitchRow gpu_power_limit_row;
        private Adw.SwitchRow gpu_name_row;
        private Adw.SwitchRow vulkan_driver_row;
        private Adw.SwitchRow gpu_procs_row;

        // CPU rows
        private Adw.EntryRow cpu_custom_name_row;
        private Gtk.ColorDialogButton cpu_color_btn;
        private Adw.SwitchRow cpu_stats_row;
        private Adw.SwitchRow cpu_load_color_row;
        private Gtk.ColorDialogButton cpu_load_color_1_btn;
        private Gtk.ColorDialogButton cpu_load_color_2_btn;
        private Gtk.ColorDialogButton cpu_load_color_3_btn;
        private Adw.SwitchRow core_load_row;
        private Adw.SwitchRow cpu_mhz_row;
        private Adw.SwitchRow core_pipeline_row;
        private Adw.SwitchRow cpu_temp_row;
        private Adw.SwitchRow cpu_power_row;
        private Adw.SwitchRow cpu_efficiency_row;
        private Adw.SwitchRow ram_temp_row;
        private Adw.SwitchRow ram_row;
        private Adw.SwitchRow disks_row;
        private Adw.SwitchRow cpu_procs_row;
        private Adw.SwitchRow swap_row;

        public MangoHudMetricsPage (Models.MangoHudConfig config) {
            base (config);

            // GPU section
            var gpu_metrics_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var gpu_label = new Gtk.Label (_ ("GPU")) {
                halign = Gtk.Align.START,
                margin_start = 12
            };
            gpu_label.add_css_class ("heading");
            gpu_metrics_box.append (gpu_label);

            var color_dialog = new Gtk.ColorDialog ();
            gpu_color_btn = new Gtk.ColorDialogButton (color_dialog);
            gpu_color_btn.set_valign (Gtk.Align.CENTER);
            refresh_gpu_color_btn ();
            gpu_color_btn.notify["rgba"].connect (() => {
                if (is_updating) return;
                var rgba = gpu_color_btn.get_rgba ();
                config.gpu_color = "%02x%02x%02x".printf ((uint) (rgba.red * 255), (uint) (rgba.green * 255), (uint) (rgba.blue * 255));
                config.save ();
            });

            gpu_custom_name_row = new Adw.EntryRow () {
                title = _ ("Custom GPU name"),
                text = config.gpu_text
            };
            gpu_custom_name_row.add_suffix (gpu_color_btn);
            gpu_custom_name_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.gpu_text = gpu_custom_name_row.text;
                config.save ();
            });
            var gpu_custom_flow_box = create_flow_box ();
            gpu_custom_flow_box.append (create_row_card (gpu_custom_name_row));
            add_group_to_page (gpu_metrics_box, null, gpu_custom_flow_box, "caption");

            gpu_stats_row = create_switch (_ ("GPU Stats"), config.gpu_stats, (val) => { config.gpu_stats = val; });

            gpu_load_color_row = create_switch (_ ("GPU Load Color"), config.gpu_load_color, (val) => { config.gpu_load_color = val; });
            gpu_load_color_1_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            gpu_load_color_2_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            gpu_load_color_3_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            var gpu_load_color_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            gpu_load_color_box.append (gpu_load_color_1_btn);
            gpu_load_color_box.append (gpu_load_color_2_btn);
            gpu_load_color_box.append (gpu_load_color_3_btn);
            gpu_load_color_row.add_suffix (gpu_load_color_box);
            gpu_load_color_row.bind_property ("active", gpu_load_color_box, "visible", BindingFlags.SYNC_CREATE);
            refresh_gpu_load_color_btns ();

            gpu_load_color_1_btn.notify["rgba"].connect (update_gpu_load_colors);
            gpu_load_color_2_btn.notify["rgba"].connect (update_gpu_load_colors);
            gpu_load_color_3_btn.notify["rgba"].connect (update_gpu_load_colors);

            vram_row = create_switch (_ ("VRAM"), config.vram, (val) => { config.vram = val; });
            gpu_core_clock_row = create_switch (_ ("GPU Core Clock"), config.gpu_core_clock, (val) => { config.gpu_core_clock = val; });
            gpu_mem_clock_row = create_switch (_ ("GPU Memory Clock"), config.gpu_mem_clock, (val) => { config.gpu_mem_clock = val; });
            
            var gpu_main_flow_box = create_flow_box ();
            gpu_main_flow_box.append (create_row_card (gpu_stats_row));
            gpu_main_flow_box.append (create_row_card (gpu_load_color_row));
            gpu_main_flow_box.append (create_row_card (vram_row));
            gpu_main_flow_box.append (create_row_card (gpu_core_clock_row));
            gpu_main_flow_box.append (create_row_card (gpu_mem_clock_row));
            add_group_to_page (gpu_metrics_box, _ ("Main metrics"), gpu_main_flow_box, "caption");

            gpu_temp_row = create_switch (_ ("GPU Temperature"), config.gpu_temp, (val) => { config.gpu_temp = val; });
            gpu_mem_temp_row = create_switch (_ ("GPU Memory Temperature"), config.gpu_mem_temp, (val) => { config.gpu_mem_temp = val; });
            gpu_junction_temp_row = create_switch (_ ("GPU Junction Temperature"), config.gpu_junction_temp, (val) => { config.gpu_junction_temp = val; });
            gpu_fan_row = create_switch (_ ("GPU Fan"), config.gpu_fan, (val) => { config.gpu_fan = val; });

            var gpu_temp_flow_box = create_flow_box ();
            gpu_temp_flow_box.append (create_row_card (gpu_temp_row));
            gpu_temp_flow_box.append (create_row_card (gpu_mem_temp_row));
            gpu_temp_flow_box.append (create_row_card (gpu_junction_temp_row));
            gpu_temp_flow_box.append (create_row_card (gpu_fan_row));
            add_group_to_page (gpu_metrics_box, _ ("Temperature"), gpu_temp_flow_box, "caption");

            gpu_power_row = create_switch (_ ("GPU Power"), config.gpu_power, (val) => { config.gpu_power = val; });
            gpu_voltage_row = create_switch (_ ("GPU Voltage"), config.gpu_voltage, (val) => { config.gpu_voltage = val; });
            throttling_status_row = create_switch (_ ("Throttling Status"), config.throttling_status, (val) => { config.throttling_status = val; });
            throttling_graph_row = create_switch (_ ("Throttling Graph"), config.throttling_graph, (val) => { config.throttling_graph = val; });
            gpu_efficiency_row = create_switch (_ ("GPU Efficiency"), config.gpu_efficiency, (val) => { config.gpu_efficiency = val; });
            gpu_power_limit_row = create_switch (_ ("GPU Power Limit"), config.gpu_power_limit, (val) => { config.gpu_power_limit = val; });

            var gpu_power_flow_box = create_flow_box ();
            gpu_power_flow_box.append (create_row_card (gpu_power_row));
            gpu_power_flow_box.append (create_row_card (gpu_voltage_row));
            gpu_power_flow_box.append (create_row_card (throttling_status_row));
            gpu_power_flow_box.append (create_row_card (throttling_graph_row));
            gpu_power_flow_box.append (create_row_card (gpu_efficiency_row));
            gpu_power_flow_box.append (create_row_card (gpu_power_limit_row));
            add_group_to_page (gpu_metrics_box, _ ("Power"), gpu_power_flow_box, "caption");

            gpu_name_row = create_switch (_ ("GPU Name"), config.gpu_name, (val) => { config.gpu_name = val; });
            vulkan_driver_row = create_switch (_ ("Vulkan Driver"), config.vulkan_driver, (val) => { config.vulkan_driver = val; });
            gpu_procs_row = create_switch (_ ("GPU Processes"), config.procs, (val) => { config.procs = val; });

            var gpu_info_flow_box = create_flow_box ();
            gpu_info_flow_box.append (create_row_card (gpu_name_row));
            gpu_info_flow_box.append (create_row_card (vulkan_driver_row));
            gpu_info_flow_box.append (create_row_card (gpu_procs_row));
            add_group_to_page (gpu_metrics_box, _ ("Information"), gpu_info_flow_box, "caption");

            this.append (gpu_metrics_box);

            // CPU section
            var cpu_metrics_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var cpu_label = new Gtk.Label (_ ("CPU")) {
                halign = Gtk.Align.START,
                margin_start = 12
            };
            cpu_label.add_css_class ("heading");
            cpu_metrics_box.append (cpu_label);

            cpu_color_btn = new Gtk.ColorDialogButton (color_dialog);
            cpu_color_btn.set_valign (Gtk.Align.CENTER);
            refresh_cpu_color_btn ();
            cpu_color_btn.notify["rgba"].connect (() => {
                if (is_updating) return;
                var rgba = cpu_color_btn.get_rgba ();
                config.cpu_color = "%02x%02x%02x".printf ((uint) (rgba.red * 255), (uint) (rgba.green * 255), (uint) (rgba.blue * 255));
                config.save ();
            });

            cpu_custom_name_row = new Adw.EntryRow () {
                title = _ ("Custom CPU name"),
                text = config.cpu_text
            };
            cpu_custom_name_row.add_suffix (cpu_color_btn);
            cpu_custom_name_row.notify["text"].connect (() => {
                if (is_updating) return;
                config.cpu_text = cpu_custom_name_row.text;
                config.save ();
            });
            var cpu_custom_flow_box = create_flow_box ();
            cpu_custom_flow_box.append (create_row_card (cpu_custom_name_row));
            add_group_to_page (cpu_metrics_box, null, cpu_custom_flow_box, "caption");

            cpu_stats_row = create_switch (_ ("CPU Stats"), config.cpu_stats, (val) => { config.cpu_stats = val; });
            
            cpu_load_color_row = create_switch (_ ("CPU Load Color"), config.cpu_load_color, (val) => { config.cpu_load_color = val; });
            cpu_load_color_1_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            cpu_load_color_2_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            cpu_load_color_3_btn = new Gtk.ColorDialogButton (color_dialog) { valign = Gtk.Align.CENTER };
            var cpu_load_color_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            cpu_load_color_box.append (cpu_load_color_1_btn);
            cpu_load_color_box.append (cpu_load_color_2_btn);
            cpu_load_color_box.append (cpu_load_color_3_btn);
            cpu_load_color_row.add_suffix (cpu_load_color_box);
            cpu_load_color_row.bind_property ("active", cpu_load_color_box, "visible", BindingFlags.SYNC_CREATE);
            refresh_cpu_load_color_btns ();

            cpu_load_color_1_btn.notify["rgba"].connect (update_cpu_load_colors);
            cpu_load_color_2_btn.notify["rgba"].connect (update_cpu_load_colors);
            cpu_load_color_3_btn.notify["rgba"].connect (update_cpu_load_colors);

            core_load_row = create_switch (_ ("Core Load"), config.core_load, (val) => { config.core_load = val; });
            cpu_mhz_row = create_switch (_ ("CPU MHz"), config.cpu_mhz, (val) => { config.cpu_mhz = val; });
            core_pipeline_row = create_switch (_ ("Core Pipeline"), config.core_pipeline, (val) => { config.core_pipeline = val; });

            var cpu_main_flow_box = create_flow_box ();
            cpu_main_flow_box.append (create_row_card (cpu_stats_row));
            cpu_main_flow_box.append (create_row_card (cpu_load_color_row));
            cpu_main_flow_box.append (create_row_card (core_load_row));
            cpu_main_flow_box.append (create_row_card (cpu_mhz_row));
            cpu_main_flow_box.append (create_row_card (core_pipeline_row));
            add_group_to_page (cpu_metrics_box, _ ("Main metrics"), cpu_main_flow_box, "caption");

            cpu_temp_row = create_switch (_ ("CPU Temperature"), config.cpu_temp, (val) => { config.cpu_temp = val; });
            cpu_power_row = create_switch (_ ("CPU Power"), config.cpu_power, (val) => { config.cpu_power = val; });
            cpu_efficiency_row = create_switch (_ ("CPU Efficiency"), config.cpu_efficiency, (val) => { config.cpu_efficiency = val; });
            ram_temp_row = create_switch (_ ("RAM Temperature"), config.ram_temp, (val) => { config.ram_temp = val; });

            var cpu_temp_power_flow_box = create_flow_box ();
            cpu_temp_power_flow_box.append (create_row_card (cpu_temp_row));
            cpu_temp_power_flow_box.append (create_row_card (cpu_power_row));
            cpu_temp_power_flow_box.append (create_row_card (cpu_efficiency_row));
            cpu_temp_power_flow_box.append (create_row_card (ram_temp_row));
            add_group_to_page (cpu_metrics_box, _ ("Temperature / Power"), cpu_temp_power_flow_box, "caption");

            ram_row = create_switch (_ ("RAM"), config.ram, (val) => { config.ram = val; });
            disks_row = create_switch (_ ("Disks"), config.disks, (val) => { config.disks = val; });
            cpu_procs_row = create_switch (_ ("CPU Processes"), config.procs, (val) => { config.procs = val; });
            swap_row = create_switch (_ ("Swap"), config.swap, (val) => { config.swap = val; });

            var mem_flow_box = create_flow_box ();
            mem_flow_box.append (create_row_card (ram_row));
            mem_flow_box.append (create_row_card (disks_row));
            mem_flow_box.append (create_row_card (cpu_procs_row));
            mem_flow_box.append (create_row_card (swap_row));
            add_group_to_page (cpu_metrics_box, _ ("Memory / IO"), mem_flow_box, "caption");

            this.append (cpu_metrics_box);
        }

        private delegate void SetValueFunc (bool val);

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

        private void update_gpu_load_colors () {
            if (is_updating) return;
            var c1 = gpu_load_color_1_btn.get_rgba ();
            var c2 = gpu_load_color_2_btn.get_rgba ();
            var c3 = gpu_load_color_3_btn.get_rgba ();
            config.gpu_load_colors = "%02x%02x%02x,%02x%02x%02x,%02x%02x%02x".printf (
                (uint) (c1.red * 255), (uint) (c1.green * 255), (uint) (c1.blue * 255),
                (uint) (c2.red * 255), (uint) (c2.green * 255), (uint) (c2.blue * 255),
                (uint) (c3.red * 255), (uint) (c3.green * 255), (uint) (c3.blue * 255)
            );
            config.save ();
        }

        private void update_cpu_load_colors () {
            if (is_updating) return;
            var c1 = cpu_load_color_1_btn.get_rgba ();
            var c2 = cpu_load_color_2_btn.get_rgba ();
            var c3 = cpu_load_color_3_btn.get_rgba ();
            config.cpu_load_colors = "%02x%02x%02x,%02x%02x%02x,%02x%02x%02x".printf (
                (uint) (c1.red * 255), (uint) (c1.green * 255), (uint) (c1.blue * 255),
                (uint) (c2.red * 255), (uint) (c2.green * 255), (uint) (c2.blue * 255),
                (uint) (c3.red * 255), (uint) (c3.green * 255), (uint) (c3.blue * 255)
            );
            config.save ();
        }

        private void refresh_gpu_color_btn () {
            var gpu_rgba = Gdk.RGBA ();
            if (config.gpu_color != "") {
                gpu_rgba.parse ("#" + config.gpu_color);
            } else {
                gpu_rgba.parse ("#ffffff");
            }
            gpu_color_btn.rgba = gpu_rgba;
        }

        private void refresh_cpu_color_btn () {
            var cpu_rgba = Gdk.RGBA ();
            if (config.cpu_color != "") {
                cpu_rgba.parse ("#" + config.cpu_color);
            } else {
                cpu_rgba.parse ("#ffffff");
            }
            cpu_color_btn.rgba = cpu_rgba;
        }

        private void refresh_gpu_load_color_btns () {
            var gpu_load_colors = config.gpu_load_colors.split (",");
            if (gpu_load_colors.length == 3) {
                var rgba1 = Gdk.RGBA (); rgba1.parse ("#" + gpu_load_colors[0]); gpu_load_color_1_btn.rgba = rgba1;
                var rgba2 = Gdk.RGBA (); rgba2.parse ("#" + gpu_load_colors[1]); gpu_load_color_2_btn.rgba = rgba2;
                var rgba3 = Gdk.RGBA (); rgba3.parse ("#" + gpu_load_colors[2]); gpu_load_color_3_btn.rgba = rgba3;
            }
        }

        private void refresh_cpu_load_color_btns () {
            var cpu_load_colors = config.cpu_load_colors.split (",");
            if (cpu_load_colors.length == 3) {
                var rgba1 = Gdk.RGBA (); rgba1.parse ("#" + cpu_load_colors[0]); cpu_load_color_1_btn.rgba = rgba1;
                var rgba2 = Gdk.RGBA (); rgba2.parse ("#" + cpu_load_colors[1]); cpu_load_color_2_btn.rgba = rgba2;
                var rgba3 = Gdk.RGBA (); rgba3.parse ("#" + cpu_load_colors[2]); cpu_load_color_3_btn.rgba = rgba3;
            }
        }

        public override void refresh () {
            is_updating = true;
            gpu_custom_name_row.text = config.gpu_text;
            refresh_gpu_color_btn ();
            gpu_stats_row.active = config.gpu_stats;
            gpu_load_color_row.active = config.gpu_load_color;
            refresh_gpu_load_color_btns ();
            vram_row.active = config.vram;
            gpu_core_clock_row.active = config.gpu_core_clock;
            gpu_mem_clock_row.active = config.gpu_mem_clock;
            gpu_temp_row.active = config.gpu_temp;
            gpu_mem_temp_row.active = config.gpu_mem_temp;
            gpu_junction_temp_row.active = config.gpu_junction_temp;
            gpu_fan_row.active = config.gpu_fan;
            gpu_power_row.active = config.gpu_power;
            gpu_voltage_row.active = config.gpu_voltage;
            throttling_status_row.active = config.throttling_status;
            throttling_graph_row.active = config.throttling_graph;
            gpu_efficiency_row.active = config.gpu_efficiency;
            gpu_power_limit_row.active = config.gpu_power_limit;
            gpu_name_row.active = config.gpu_name;
            vulkan_driver_row.active = config.vulkan_driver;
            gpu_procs_row.active = config.procs;

            cpu_custom_name_row.text = config.cpu_text;
            refresh_cpu_color_btn ();
            cpu_stats_row.active = config.cpu_stats;
            cpu_load_color_row.active = config.cpu_load_color;
            refresh_cpu_load_color_btns ();
            core_load_row.active = config.core_load;
            cpu_mhz_row.active = config.cpu_mhz;
            core_pipeline_row.active = config.core_pipeline;
            cpu_temp_row.active = config.cpu_temp;
            cpu_power_row.active = config.cpu_power;
            cpu_efficiency_row.active = config.cpu_efficiency;
            ram_temp_row.active = config.ram_temp;
            ram_row.active = config.ram;
            disks_row.active = config.disks;
            cpu_procs_row.active = config.procs;
            swap_row.active = config.swap;
            is_updating = false;
        }
    }
}
