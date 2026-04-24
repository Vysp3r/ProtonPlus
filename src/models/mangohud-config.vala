using Gee;

namespace ProtonPlus.Models {
    public enum MangoHudPreset {
        CUSTOM,
        FULL,
        BASIC,
        BASIC_HORIZONTAL,
        FPS_ONLY
    }

    public enum MangoHudTheme {
        STOCK,
        SIMPLE_WHITE,
        CUSTOM
    }

    public class MangoHudConfig : Object {
        public string fps_limit { get; set; default = "0"; }
        public string position { get; set; default = "top-left"; }
        public bool cpu_stats { get; set; default = false; }
        public bool cpu_temp { get; set; default = false; }
        public bool gpu_stats { get; set; default = false; }
        public bool gpu_temp { get; set; default = false; }
        public bool ram { get; set; default = false; }
        public bool vram { get; set; default = false; }
        public bool fps { get; set; default = false; }
        public bool frametime { get; set; default = false; }
        public bool battery { get; set; default = false; }
        public bool time { get; set; default = false; }
        public bool horizontal { get; set; default = false; }
        public string font_size { get; set; default = "24"; }
        public bool gpu_core_clock { get; set; default = false; }
        public bool gpu_mem_clock { get; set; default = false; }
        public bool gpu_mem_temp { get; set; default = false; }
        public bool gpu_junction_temp { get; set; default = false; }
        public bool gpu_fan { get; set; default = false; }
        public bool gpu_power { get; set; default = false; }
        public bool gpu_voltage { get; set; default = false; }
        public bool throttling_status { get; set; default = false; }
        public bool gpu_efficiency { get; set; default = false; }
        public bool gpu_power_limit { get; set; default = false; }
        public bool gpu_load_color { get; set; default = false; }
        public string gpu_load_colors { get; set; default = "00ff00,ffff00,ff0000"; }
        public bool throttling_graph { get; set; default = false; }
        public bool gpu_name { get; set; default = false; }
        public string gpu_text { get; set; default = ""; }
        public string gpu_color { get; set; default = ""; }
        public bool vulkan_driver { get; set; default = false; }
        public bool core_load { get; set; default = false; }
        public bool cpu_load_color { get; set; default = false; }
        public string cpu_load_colors { get; set; default = "00ff00,ffff00,ff0000"; }
        public string cpu_text { get; set; default = ""; }
        public string cpu_color { get; set; default = ""; }
        public string ram_color { get; set; default = ""; }
        public string vram_color { get; set; default = ""; }
        public string disks_color { get; set; default = ""; }
        public string wine_color { get; set; default = ""; }
        public string engine_color { get; set; default = ""; }
        public string battery_color { get; set; default = ""; }
        public string media_player_color { get; set; default = ""; }
        public bool core_load_change { get; set; default = false; }
        public bool core_pipeline { get; set; default = false; }
        public bool cpu_mhz { get; set; default = false; }
        public bool cpu_efficiency { get; set; default = false; }
        public bool cpu_power { get; set; default = false; }
        public bool ram_temp { get; set; default = false; }
        public bool swap { get; set; default = false; }
        public bool disks { get; set; default = false; }
        public bool distro { get; set; default = false; }
        public bool refresh_rate { get; set; default = false; }
        public bool resolution { get; set; default = false; }
        public bool display_server { get; set; default = false; }
        public bool arch { get; set; default = false; }
        public bool wine { get; set; default = false; }
        public bool engine_version { get; set; default = false; }
        public bool engine_short_names { get; set; default = false; }
        public bool wine_sync { get; set; default = false; }
        public bool dx_api { get; set; default = false; }
        public bool fex_stats { get; set; default = false; }
        public bool hud_version { get; set; default = false; }
        public bool gamemode { get; set; default = false; }
        public bool vkbasalt { get; set; default = false; }
        public bool fcat { get; set; default = false; }
        public bool fsr { get; set; default = false; }
        public bool hdr { get; set; default = false; }
        public bool battery_wattage { get; set; default = false; }
        public bool battery_time { get; set; default = false; }
        public bool device_battery { get; set; default = false; }
        public bool media_player { get; set; default = false; }
        public string network { get; set; default = ""; }
        public bool fahrenheit { get; set; default = false; }
        public string custom_text { get; set; default = ""; }
        public bool procs { get; set; default = false; }
        public int round_corners { get; set; default = 0; }
        public int table_columns { get; set; default = 0; }
        public string background_color { get; set; default = "020202"; }
        public string background_alpha { get; set; default = "0.5"; }
        public string text_color { get; set; default = "ffffff"; }
        public bool compact { get; set; default = false; }
        public bool no_display { get; set; default = false; }
        public string hud_title { get; set; default = ""; }
        public string toggle_hud { get; set; default = "Shift_R+F12"; }
        public string log_duration { get; set; default = ""; }
        public string log_interval { get; set; default = ""; }
        public string autostart_log { get; set; default = ""; }
        public string toggle_logging { get; set; default = ""; }
        public string output_folder { get; set; default = ""; }
        public bool upload_log { get; set; default = false; }
        public bool log_versioning { get; set; default = false; }
        public bool fps_avg { get; set; default = false; }
        public bool fps_limit_stats { get; set; default = false; }
        public bool frame_count { get; set; default = false; }
        public bool vps { get; set; default = false; }
        public bool ftrace { get; set; default = false; }
        public string vsync { get; set; default = ""; }
        public string gl_vsync { get; set; default = ""; }
        public string fps_limit_method { get; set; default = ""; }
        public string toggle_fps_limit { get; set; default = ""; }
        public int fps_limit_offset { get; set; default = 0; }
        public bool change_fps_limit_colors { get; set; default = false; }
        public string fps_limit_colors { get; set; default = "ff0000,ffff00,00ff00"; }
        public string af { get; set; default = ""; }
        public string picmip { get; set; default = ""; }
        public string lod_bias { get; set; default = ""; }

        private string config_path;
        private Gee.HashMap<string, string> unknown_settings;

        public MangoHudConfig () {
            config_path = Path.build_filename (Environment.get_user_config_dir (), "MangoHud", "MangoHud.conf");
            unknown_settings = new Gee.HashMap<string, string> ();
        }

        public void set_preset (MangoHudPreset preset) {
            switch (preset) {
                case MangoHudPreset.FULL:
                    cpu_stats = true;
                    cpu_temp = true;
                    gpu_stats = true;
                    gpu_temp = true;
                    ram = true;
                    vram = true;
                    fps = true;
                    frametime = true;
                    battery = true;
                    device_battery = true;
                    time = true;
                    horizontal = false;
                    break;
                case MangoHudPreset.BASIC:
                    cpu_stats = true;
                    cpu_temp = false;
                    gpu_stats = true;
                    gpu_temp = false;
                    ram = true;
                    vram = false;
                    fps = true;
                    frametime = false;
                    battery = false;
                    device_battery = false;
                    time = false;
                    horizontal = false;
                    break;
                case MangoHudPreset.BASIC_HORIZONTAL:
                    cpu_stats = true;
                    cpu_temp = false;
                    gpu_stats = true;
                    gpu_temp = false;
                    ram = true;
                    vram = false;
                    fps = true;
                    frametime = false;
                    battery = false;
                    device_battery = false;
                    time = false;
                    horizontal = true;
                    break;
                case MangoHudPreset.FPS_ONLY:
                    cpu_stats = false;
                    cpu_temp = false;
                    gpu_stats = false;
                    gpu_temp = false;
                    ram = false;
                    vram = false;
                    fps = true;
                    frametime = false;
                    battery = false;
                    device_battery = false;
                    time = false;
                    horizontal = false;
                    break;
                case MangoHudPreset.CUSTOM:
                default:
                    break;
            }
        }

        public void set_theme (MangoHudTheme theme) {
            switch (theme) {
                case MangoHudTheme.STOCK:
                    gpu_color = "";
                    cpu_color = "";
                    vram_color = "";
                    ram_color = "";
                    engine_color = "";
                    wine_color = "";
                    battery_color = "";
                    disks_color = "";
                    media_player_color = "";
                    text_color = "ffffff";
                    background_color = "020202";
                    break;
                case MangoHudTheme.SIMPLE_WHITE:
                    gpu_color = "ffffff";
                    cpu_color = "ffffff";
                    vram_color = "ffffff";
                    ram_color = "ffffff";
                    engine_color = "ffffff";
                    wine_color = "ffffff";
                    battery_color = "ffffff";
                    disks_color = "ffffff";
                    media_player_color = "ffffff";
                    text_color = "ffffff";
                    background_color = "020202";
                    break;
                case MangoHudTheme.CUSTOM:
                default:
                    break;
            }
        }

        public MangoHudPreset get_preset () {
            if (horizontal && cpu_stats && gpu_stats && ram && fps && !cpu_temp && !gpu_temp && !vram && !frametime && !battery && !device_battery && !time)
            return MangoHudPreset.BASIC_HORIZONTAL;
            if (!horizontal && cpu_stats && gpu_stats && ram && fps && !cpu_temp && !gpu_temp && !vram && !frametime && !battery && !device_battery && !time)
            return MangoHudPreset.BASIC;
            if (!horizontal && fps && !cpu_stats && !gpu_stats && !ram && !vram && !cpu_temp && !gpu_temp && !frametime && !battery && !device_battery && !time)
            return MangoHudPreset.FPS_ONLY;
            if (!horizontal && cpu_stats && cpu_temp && gpu_stats && gpu_temp && ram && vram && fps && frametime && battery && device_battery && time)
            return MangoHudPreset.FULL;
            return MangoHudPreset.CUSTOM;
        }

        public MangoHudTheme get_theme () {
            if (gpu_color == "" && cpu_color == "" && vram_color == "" && ram_color == "" && engine_color == "" && wine_color == "" && battery_color == "" && disks_color == "" && media_player_color == "" && text_color == "ffffff" && background_color == "020202")
            return MangoHudTheme.STOCK;
            if (gpu_color == "ffffff" && cpu_color == "ffffff" && vram_color == "ffffff" && ram_color == "ffffff" && engine_color == "ffffff" && wine_color == "ffffff" && battery_color == "ffffff" && disks_color == "ffffff" && media_player_color == "ffffff" && text_color == "ffffff" && background_color == "020202")
            return MangoHudTheme.SIMPLE_WHITE;
            return MangoHudTheme.CUSTOM;
        }

        public void load () {
            if (!FileUtils.test (config_path, FileTest.EXISTS)) {
                return;
            }

            try {
                string content;
                FileUtils.get_contents (config_path, out content);

                unknown_settings.clear ();
                var lines = content.split ("\n");
                foreach (var line in lines) {
                    var trimmed = line.strip ();
                    if (trimmed.has_prefix ("#") || trimmed == "") {
                        continue;
                    }

                    var parts = trimmed.split ("=", 2);
                    var key = parts[0].strip ();
                    var val = parts.length > 1 ? parts[1].strip () : "";

                    switch (key) {
                        case "fps_limit":
                            fps_limit = val;
                            break;
                        case "position":
                            position = val;
                            break;
                        case "cpu_stats":
                            cpu_stats = (val != "0");
                            break;
                        case "cpu_temp":
                            cpu_temp = (val != "0");
                            break;
                        case "gpu_stats":
                            gpu_stats = (val != "0");
                            break;
                        case "gpu_temp":
                            gpu_temp = (val != "0");
                            break;
                        case "ram":
                            ram = (val != "0");
                            break;
                        case "vram":
                            vram = (val != "0");
                            break;
                        case "fps":
                            fps = (val != "0");
                            break;
                        case "frametime":
                            frametime = (val != "0");
                            break;
                        case "battery":
                            battery = (val != "0");
                            break;
                        case "time":
                            time = (val != "0");
                            break;
                        case "horizontal":
                            horizontal = (val != "0");
                            break;
                        case "font_size":
                            font_size = val;
                            break;
                        case "gpu_core_clock":
                            gpu_core_clock = (val != "0");
                            break;
                        case "gpu_mem_clock":
                            gpu_mem_clock = (val != "0");
                            break;
                        case "gpu_mem_temp":
                            gpu_mem_temp = (val != "0");
                            break;
                        case "gpu_junction_temp":
                            gpu_junction_temp = (val != "0");
                            break;
                        case "gpu_fan":
                            gpu_fan = (val != "0");
                            break;
                        case "gpu_power":
                            gpu_power = (val != "0");
                            break;
                        case "gpu_voltage":
                            gpu_voltage = (val != "0");
                            break;
                        case "throttling_status":
                            throttling_status = (val != "0");
                            break;
                        case "gpu_efficiency":
                            gpu_efficiency = (val != "0");
                            break;
                        case "gpu_power_limit":
                            gpu_power_limit = (val != "0");
                            break;
                        case "gpu_load_color":
                            gpu_load_color = (val != "0");
                            if (val != "" && val != "1" && val != "0") {
                                gpu_load_colors = val;
                            }
                            break;
                        case "throttling_graph":
                            throttling_graph = (val != "0");
                            break;
                        case "gpu_name":
                            gpu_name = (val != "0");
                            break;
                        case "gpu_text":
                            gpu_text = val;
                            break;
                        case "gpu_color":
                            gpu_color = val;
                            break;
                        case "vulkan_driver":
                            vulkan_driver = (val != "0");
                            break;
                        case "core_load":
                            core_load = (val != "0");
                            break;
                        case "cpu_load_color":
                            cpu_load_color = (val != "0");
                            if (val != "" && val != "1" && val != "0") {
                                cpu_load_colors = val;
                            }
                            break;
                        case "cpu_text":
                            cpu_text = val;
                            break;
                        case "cpu_color":
                            cpu_color = val;
                            break;
                        case "ram_color":
                            ram_color = val;
                            break;
                        case "vram_color":
                            vram_color = val;
                            break;
                        case "disks_color":
                            disks_color = val;
                            break;
                        case "wine_color":
                            wine_color = val;
                            break;
                        case "engine_color":
                            engine_color = val;
                            break;
                        case "battery_color":
                            battery_color = val;
                            break;
                        case "media_player_color":
                            media_player_color = val;
                            break;
                        case "core_load_change":
                            core_load_change = (val != "0");
                            break;
                        case "core_pipeline":
                            core_pipeline = (val != "0");
                            break;
                        case "cpu_mhz":
                            cpu_mhz = (val != "0");
                            break;
                        case "cpu_efficiency":
                            cpu_efficiency = (val != "0");
                            break;
                        case "cpu_power":
                            cpu_power = (val != "0");
                            break;
                        case "ram_temp":
                            ram_temp = (val != "0");
                            break;
                        case "swap":
                            swap = (val != "0");
                            break;
                        case "disks":
                            disks = (val != "0");
                            break;
                        case "distro":
                            distro = (val != "0");
                            break;
                        case "refresh_rate":
                            refresh_rate = (val != "0");
                            break;
                        case "resolution":
                            resolution = (val != "0");
                            break;
                        case "display_server":
                            display_server = (val != "0");
                            break;
                        case "arch":
                            arch = (val != "0");
                            break;
                        case "wine":
                            wine = (val != "0");
                            break;
                        case "engine_version":
                            engine_version = (val != "0");
                            break;
                        case "engine_short_names":
                            engine_short_names = (val != "0");
                            break;
                        case "wine_sync":
                            wine_sync = (val != "0");
                            break;
                        case "dx_api":
                            dx_api = (val != "0");
                            break;
                        case "fex_stats":
                            fex_stats = (val != "0");
                            break;
                        case "hud_version":
                            hud_version = (val != "0");
                            break;
                        case "gamemode":
                            gamemode = (val != "0");
                            break;
                        case "vkbasalt":
                            vkbasalt = (val != "0");
                            break;
                        case "fcat":
                            fcat = (val != "0");
                            break;
                        case "fsr":
                            fsr = (val != "0");
                            break;
                        case "hdr":
                            hdr = (val != "0");
                            break;
                        case "battery_wattage":
                            battery_wattage = (val != "0");
                            break;
                        case "battery_time":
                            battery_time = (val != "0");
                            break;
                        case "device_battery":
                            device_battery = (val != "0");
                            break;
                        case "media_player":
                            media_player = (val != "0");
                            break;
                        case "network":
                            network = val;
                            break;
                        case "fahrenheit":
                            fahrenheit = (val != "0");
                            break;
                        case "custom_text":
                            custom_text = val;
                            break;
                        case "procs":
                            procs = (val != "0");
                            break;
                        case "round_corners":
                            round_corners = int.parse (val);
                            break;
                        case "table_columns":
                            table_columns = int.parse (val);
                            break;
                        case "background_color":
                            background_color = val;
                            break;
                        case "background_alpha":
                            background_alpha = val;
                            break;
                        case "text_color":
                            text_color = val;
                            break;
                        case "compact":
                            compact = (val != "0");
                            break;
                        case "no_display":
                            no_display = (val != "0");
                            break;
                        case "hud_title":
                            hud_title = val;
                            break;
                        case "toggle_hud":
                            toggle_hud = val;
                            break;
                        case "log_duration":
                            log_duration = val;
                            break;
                        case "log_interval":
                            log_interval = val;
                            break;
                        case "autostart_log":
                            autostart_log = val;
                            break;
                        case "toggle_logging":
                            toggle_logging = val;
                            break;
                        case "upload_log":
                            upload_log = (val != "0");
                            break;
                        case "log_versioning":
                            log_versioning = (val != "0");
                            break;
                        case "output_folder":
                            output_folder = val;
                            break;
                        case "fps_metrics":
                            fps_avg = val.contains ("avg");
                            fps_limit_stats = val.contains ("fps_limit");
                            break;
                        case "frame_count":
                            frame_count = (val != "0");
                            break;
                        case "vps":
                            vps = (val != "0");
                            break;
                        case "ftrace":
                            ftrace = (val != "0");
                            break;
                        case "vsync":
                            vsync = val;
                            break;
                        case "gl_vsync":
                            gl_vsync = val;
                            break;
                        case "fps_limit_method":
                            fps_limit_method = val;
                            break;
                        case "toggle_fps_limit":
                            toggle_fps_limit = val;
                            break;
                        case "fps_limit_offset":
                            fps_limit_offset = int.parse (val);
                            break;
                        case "fps_limit_colors":
                            change_fps_limit_colors = true;
                            fps_limit_colors = val;
                            break;
                        case "af":
                            af = val;
                            break;
                        case "picmip":
                            picmip = val;
                            break;
                        case "lod_bias":
                            lod_bias = val;
                            break;
                        default:
                            unknown_settings.set (key, val);
                            break;
                    }
                }
            } catch (Error e) {
                warning ("Could not load MangoHud config: %s", e.message);
            }
        }

        public void save () {
            var dir = Path.get_dirname (config_path);
            if (!FileUtils.test (dir, FileTest.EXISTS)) {
                DirUtils.create_with_parents (dir, 0755);
            }

            var builder = new StringBuilder ();
            builder.append ("### MangoHud Configuration ###\n");
            builder.append ("### Generated by ProtonPlus ###\n\n");

            if (fps_limit != "0" && fps_limit != "") builder.append_printf ("fps_limit=%s\n", fps_limit);
            builder.append_printf ("position=%s\n", position);
            if (cpu_stats) builder.append ("cpu_stats\n");
            if (cpu_temp) builder.append ("cpu_temp\n");
            if (gpu_stats) builder.append ("gpu_stats\n");
            if (gpu_temp) builder.append ("gpu_temp\n");
            if (ram) builder.append ("ram\n");
            if (vram) builder.append ("vram\n");
            if (fps) builder.append ("fps\n");
            if (frametime) builder.append ("frametime\n");
            if (battery) builder.append ("battery\n");
            if (time) builder.append ("time\n");
            if (horizontal) builder.append ("horizontal\n");
            if (font_size != "") builder.append_printf ("font_size=%s\n", font_size);
            if (gpu_core_clock) builder.append ("gpu_core_clock\n");
            if (gpu_mem_clock) builder.append ("gpu_mem_clock\n");
            if (gpu_mem_temp) builder.append ("gpu_mem_temp\n");
            if (gpu_junction_temp) builder.append ("gpu_junction_temp\n");
            if (gpu_fan) builder.append ("gpu_fan\n");
            if (gpu_power) builder.append ("gpu_power\n");
            if (gpu_voltage) builder.append ("gpu_voltage\n");
            if (throttling_status) builder.append ("throttling_status\n");
            if (gpu_efficiency) builder.append ("gpu_efficiency\n");
            if (gpu_power_limit) builder.append ("gpu_power_limit\n");
            if (gpu_load_color) builder.append_printf ("gpu_load_color=%s\n", gpu_load_colors);
            if (throttling_graph) builder.append ("throttling_graph\n");
            if (gpu_name) builder.append ("gpu_name\n");
            if (gpu_text != "") builder.append_printf ("gpu_text=%s\n", gpu_text);
            if (gpu_color != "") builder.append_printf ("gpu_color=%s\n", gpu_color);
            if (vulkan_driver) builder.append ("vulkan_driver\n");
            if (core_load) builder.append ("core_load\n");
            if (cpu_load_color) builder.append_printf ("cpu_load_color=%s\n", cpu_load_colors);
            if (cpu_text != "") builder.append_printf ("cpu_text=%s\n", cpu_text);
            if (cpu_color != "") builder.append_printf ("cpu_color=%s\n", cpu_color);
            if (ram_color != "") builder.append_printf ("ram_color=%s\n", ram_color);
            if (vram_color != "") builder.append_printf ("vram_color=%s\n", vram_color);
            if (disks_color != "") builder.append_printf ("disks_color=%s\n", disks_color);
            if (wine_color != "") builder.append_printf ("wine_color=%s\n", wine_color);
            if (engine_color != "") builder.append_printf ("engine_color=%s\n", engine_color);
            if (battery_color != "") builder.append_printf ("battery_color=%s\n", battery_color);
            if (media_player_color != "") builder.append_printf ("media_player_color=%s\n", media_player_color);
            if (core_load_change) builder.append ("core_load_change\n");
            if (core_pipeline) builder.append ("core_pipeline\n");
            if (cpu_mhz) builder.append ("cpu_mhz\n");
            if (cpu_efficiency) builder.append ("cpu_efficiency\n");
            if (cpu_power) builder.append ("cpu_power\n");
            if (ram_temp) builder.append ("ram_temp\n");
            if (swap) builder.append ("swap\n");
            if (disks) builder.append ("disks\n");
            if (distro) builder.append ("distro\n");
            if (refresh_rate) builder.append ("refresh_rate\n");
            if (resolution) builder.append ("resolution\n");
            if (display_server) builder.append ("display_server\n");
            if (arch) builder.append ("arch\n");
            if (wine) builder.append ("wine\n");
            if (engine_version) builder.append ("engine_version\n");
            if (engine_short_names) builder.append ("engine_short_names\n");
            if (wine_sync) builder.append ("wine_sync\n");
            if (dx_api) builder.append ("dx_api\n");
            if (fex_stats) builder.append ("fex_stats\n");
            if (hud_version) builder.append ("hud_version\n");
            if (gamemode) builder.append ("gamemode\n");
            if (vkbasalt) builder.append ("vkbasalt\n");
            if (fcat) builder.append ("fcat\n");
            if (fsr) builder.append ("fsr\n");
            if (hdr) builder.append ("hdr\n");
            if (battery_wattage) builder.append ("battery_wattage\n");
            if (battery_time) builder.append ("battery_time\n");
            if (device_battery) builder.append ("device_battery\n");
            if (media_player) builder.append ("media_player\n");
            if (network != "") builder.append_printf ("network=%s\n", network);
            if (fahrenheit) builder.append ("fahrenheit\n");
            if (custom_text != "") builder.append_printf ("custom_text=%s\n", custom_text);
            if (procs) builder.append ("procs\n");
            if (round_corners != 0) builder.append_printf ("round_corners=%d\n", round_corners);
            if (table_columns != 0) builder.append_printf ("table_columns=%d\n", table_columns);
            if (background_color != "020202" && background_color != "") builder.append_printf ("background_color=%s\n", background_color);
            if (background_alpha != "0.5" && background_alpha != "") builder.append_printf ("background_alpha=%s\n", background_alpha);
            if (text_color != "ffffff" && text_color != "") builder.append_printf ("text_color=%s\n", text_color);
            if (compact) builder.append ("compact\n");
            if (no_display) builder.append ("no_display\n");
            if (hud_title != "") builder.append_printf ("hud_title=%s\n", hud_title);
            if (toggle_hud != "Shift_R+F12") builder.append_printf ("toggle_hud=%s\n", toggle_hud);
            if (log_duration != "") builder.append_printf ("log_duration=%s\n", log_duration);
            if (log_interval != "") builder.append_printf ("log_interval=%s\n", log_interval);
            if (autostart_log != "") builder.append_printf ("autostart_log=%s\n", autostart_log);
            if (toggle_logging != "") builder.append_printf ("toggle_logging=%s\n", toggle_logging);
            if (upload_log) builder.append ("upload_log\n");
            if (log_versioning) builder.append ("log_versioning\n");
            if (output_folder != "") builder.append_printf ("output_folder=%s\n", output_folder);
            if (frame_count) builder.append ("frame_count\n");
            if (vps) builder.append ("vps\n");
            if (ftrace) builder.append ("ftrace\n");
            if (vsync != "") builder.append_printf ("vsync=%s\n", vsync);
            if (gl_vsync != "") builder.append_printf ("gl_vsync=%s\n", gl_vsync);
            if (fps_limit_method != "") builder.append_printf ("fps_limit_method=%s\n", fps_limit_method);
            if (toggle_fps_limit != "") builder.append_printf ("toggle_fps_limit=%s\n", toggle_fps_limit);
            if (fps_limit_offset != 0) builder.append_printf ("fps_limit_offset=%d\n", fps_limit_offset);
            if (change_fps_limit_colors) builder.append_printf ("fps_limit_colors=%s\n", fps_limit_colors);
            if (af != "") builder.append_printf ("af=%s\n", af);
            if (picmip != "") builder.append_printf ("picmip=%s\n", picmip);
            if (lod_bias != "") builder.append_printf ("lod_bias=%s\n", lod_bias);

            var fps_metrics = new StringBuilder ();
            if (fps_avg) fps_metrics.append ("avg,");
            if (fps_limit_stats) fps_metrics.append ("fps_limit,");
            if (fps_metrics.len > 0) {
                fps_metrics.truncate (fps_metrics.len - 1);
                builder.append_printf ("fps_metrics=%s\n", fps_metrics.str);
            }

            foreach (var key in unknown_settings.keys) {
                var val = unknown_settings.get (key);
                if (val != "") {
                    builder.append_printf ("%s=%s\n", key, val);
                } else {
                    builder.append_printf ("%s\n", key);
                }
            }

            try {
                FileUtils.set_contents (config_path, builder.str);
            } catch (Error e) {
                warning ("Could not save MangoHud config: %s", e.message);
            }
        }
    }
}
