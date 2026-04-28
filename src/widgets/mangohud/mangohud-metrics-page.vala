namespace ProtonPlus.Widgets.MangoHud {
    public class MetricsPage : Page {
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

        public MetricsPage (Utils.MangoHudManager config) {
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
            gpu_color_btn = create_color_button (color_dialog, config.gpu_color, (val) => { this.config.gpu_color = val; });

            gpu_custom_name_row = create_entry (_ ("Custom GPU name"), config.gpu_text, (val) => { this.config.gpu_text = val; });
            gpu_custom_name_row.add_suffix (gpu_color_btn);
            add_flow_group (gpu_metrics_box, null, { gpu_custom_name_row });

            gpu_stats_row = create_switch (_ ("Load"), config.gpu_stats, (val) => { this.config.gpu_stats = val; });

            gpu_load_color_row = create_switch (_ ("Load Color"), config.gpu_load_color, (val) => { this.config.gpu_load_color = val; });
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

            vram_row = create_switch (_ ("VRAM"), config.vram, (val) => { this.config.vram = val; });
            gpu_core_clock_row = create_switch (_ ("Core Freq"), config.gpu_core_clock, (val) => { this.config.gpu_core_clock = val; });
            gpu_mem_clock_row = create_switch (_ ("Memory Freq"), config.gpu_mem_clock, (val) => { this.config.gpu_mem_clock = val; });

            add_flow_group (gpu_metrics_box, _ ("Main metrics"), {
                                                                     gpu_stats_row, gpu_load_color_row, vram_row, gpu_core_clock_row, gpu_mem_clock_row
                                                                 });

            gpu_temp_row = create_switch (_ ("GPU"), config.gpu_temp, (val) => { this.config.gpu_temp = val; });
            gpu_mem_temp_row = create_switch (_ ("Memory"), config.gpu_mem_temp, (val) => { this.config.gpu_mem_temp = val; });
            gpu_junction_temp_row = create_switch (_ ("Junction"), config.gpu_junction_temp, (val) => { this.config.gpu_junction_temp = val; });
            gpu_fan_row = create_switch (_ ("Fans"), config.gpu_fan, (val) => { this.config.gpu_fan = val; });

            add_flow_group (gpu_metrics_box, _ ("Temperature"), {
                                                                    gpu_temp_row, gpu_mem_temp_row, gpu_junction_temp_row, gpu_fan_row
                                                                });

            gpu_power_row = create_switch (_ ("Power"), config.gpu_power, (val) => { this.config.gpu_power = val; });
            gpu_voltage_row = create_switch (_ ("Voltage"), config.gpu_voltage, (val) => { this.config.gpu_voltage = val; });
            throttling_status_row = create_switch (_ ("Throttling"), config.throttling_status, (val) => { this.config.throttling_status = val; });
            throttling_graph_row = create_switch (_ ("Throttling Graph"), config.throttling_graph, (val) => { this.config.throttling_graph = val; });
            gpu_efficiency_row = create_switch (_ ("Efficiency"), config.gpu_efficiency, (val) => { this.config.gpu_efficiency = val; });
            gpu_power_limit_row = create_switch (_ ("Power Limit"), config.gpu_power_limit, (val) => { this.config.gpu_power_limit = val; });

            add_flow_group (gpu_metrics_box, _ ("Power"), {
                                                              gpu_power_row, gpu_voltage_row, throttling_status_row, throttling_graph_row, gpu_efficiency_row, gpu_power_limit_row
                                                          });

            gpu_name_row = create_switch (_ ("Model"), config.gpu_name, (val) => { this.config.gpu_name = val; });
            vulkan_driver_row = create_switch (_ ("Vulkan Driver"), config.vulkan_driver, (val) => { this.config.vulkan_driver = val; });
            gpu_procs_row = create_switch (_ ("Process"), config.procs, (val) => { this.config.procs = val; });

            add_flow_group (gpu_metrics_box, _ ("Information"), {
                                                                    gpu_name_row, vulkan_driver_row, gpu_procs_row
                                                                });

            this.append (gpu_metrics_box);

        // CPU section
            var cpu_metrics_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            var cpu_label = new Gtk.Label (_ ("CPU")) {
                halign = Gtk.Align.START,
                margin_start = 12
            };
            cpu_label.add_css_class ("heading");
            cpu_metrics_box.append (cpu_label);

            cpu_color_btn = create_color_button (color_dialog, config.cpu_color, (val) => { this.config.cpu_color = val; });

            cpu_custom_name_row = create_entry (_ ("Custom CPU name"), config.cpu_text, (val) => { this.config.cpu_text = val; });
            cpu_custom_name_row.add_suffix (cpu_color_btn);
            add_flow_group (cpu_metrics_box, null, { cpu_custom_name_row });

            cpu_stats_row = create_switch (_ ("Load"), config.cpu_stats, (val) => { this.config.cpu_stats = val; });

            cpu_load_color_row = create_switch (_ ("Load Color"), config.cpu_load_color, (val) => { this.config.cpu_load_color = val; });
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

            core_load_row = create_switch (_ ("Core Load"), config.core_load, (val) => { this.config.core_load = val; });
            cpu_mhz_row = create_switch (_ ("CPU Freq"), config.cpu_mhz, (val) => { this.config.cpu_mhz = val; });
            core_pipeline_row = create_switch (_ ("Core Type"), config.core_pipeline, (val) => { this.config.core_pipeline = val; });

            add_flow_group (cpu_metrics_box, _ ("Main metrics"), {
                                                                     cpu_stats_row, cpu_load_color_row, core_load_row, cpu_mhz_row, core_pipeline_row
                                                                 });

            cpu_temp_row = create_switch (_ ("CPU Temperature"), config.cpu_temp, (val) => { this.config.cpu_temp = val; });
            cpu_power_row = create_switch (_ ("CPU Power"), config.cpu_power, (val) => { this.config.cpu_power = val; });
            cpu_efficiency_row = create_switch (_ ("Efficiency"), config.cpu_efficiency, (val) => { this.config.cpu_efficiency = val; });
            ram_temp_row = create_switch (_ ("RAM Temperature"), config.ram_temp, (val) => { this.config.ram_temp = val; });

            add_flow_group (cpu_metrics_box, _ ("Temperature / Power"), {
                                                                            cpu_temp_row, cpu_power_row, cpu_efficiency_row, ram_temp_row
                                                                        });

            ram_row = create_switch (_ ("RAM"), config.ram, (val) => { this.config.ram = val; });
            disks_row = create_switch (_ ("DISK IO"), config.disks, (val) => { this.config.disks = val; });
            cpu_procs_row = create_switch (_ ("Process"), config.procs, (val) => { this.config.procs = val; });
            swap_row = create_switch (_ ("Swap"), config.swap, (val) => { this.config.swap = val; });

            add_flow_group (cpu_metrics_box, _ ("Memory / IO"), {
                                                                    ram_row, disks_row, cpu_procs_row, swap_row
                                                                });

            this.append (cpu_metrics_box);
        }

        private void update_gpu_load_colors () {
            if (is_updating) return;
            Gdk.RGBA c1, c2, c3;
            gpu_load_color_1_btn.get ("rgba", out c1);
            gpu_load_color_2_btn.get ("rgba", out c2);
            gpu_load_color_3_btn.get ("rgba", out c3);
            config.gpu_load_colors = "%s,%s,%s".printf (rgba_to_hex (c1), rgba_to_hex (c2), rgba_to_hex (c3));
            changed ();
        }

        private void update_cpu_load_colors () {
            if (is_updating) return;
            Gdk.RGBA c1, c2, c3;
            cpu_load_color_1_btn.get ("rgba", out c1);
            cpu_load_color_2_btn.get ("rgba", out c2);
            cpu_load_color_3_btn.get ("rgba", out c3);
            config.cpu_load_colors = "%s,%s,%s".printf (rgba_to_hex (c1), rgba_to_hex (c2), rgba_to_hex (c3));
            changed ();
        }

        private void refresh_gpu_color_btn () {
            gpu_color_btn.rgba = hex_to_rgba (config.gpu_color);
        }

        private void refresh_cpu_color_btn () {
            cpu_color_btn.rgba = hex_to_rgba (config.cpu_color);
        }

        private void refresh_gpu_load_color_btns () {
            var gpu_load_colors = config.gpu_load_colors.split (",");
            if (gpu_load_colors.length == 3) {
                gpu_load_color_1_btn.rgba = hex_to_rgba (gpu_load_colors[0]);
                gpu_load_color_2_btn.rgba = hex_to_rgba (gpu_load_colors[1]);
                gpu_load_color_3_btn.rgba = hex_to_rgba (gpu_load_colors[2]);
            }
        }

        private void refresh_cpu_load_color_btns () {
            var cpu_load_colors = config.cpu_load_colors.split (",");
            if (cpu_load_colors.length == 3) {
                cpu_load_color_1_btn.rgba = hex_to_rgba (cpu_load_colors[0]);
                cpu_load_color_2_btn.rgba = hex_to_rgba (cpu_load_colors[1]);
                cpu_load_color_3_btn.rgba = hex_to_rgba (cpu_load_colors[2]);
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
