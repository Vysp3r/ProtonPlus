namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    enum WrapperMode {
        NONE,
        GAMESCOPE,
        SCOPEBUDDY
    }

    public class Box : Gtk.Box {
        public signal void content_changed ();

        Adw.PreferencesGroup proton_options_group { get; set; }
        Adw.PreferencesGroup audio_group { get; set; }
        Adw.PreferencesGroup more_options_group { get; set; }
        Adw.PreferencesGroup gpu_vendor_group { get; set; }
        Adw.PreferencesGroup game_arguments_group { get; set; }
        Adw.PreferencesGroup advanced_options_group { get; set; }
        LaunchOptionTile hdr_tile { get; set; }
        LaunchOptionTile vkbasalt_tile { get; set; }
        LaunchOptionTile wined3d_tile { get; set; }
        LaunchOptionTile amd_fsr4_upgrade_tile { get; set; }
        LaunchOptionTile amd_fsr4_rdna3_upgrade_tile { get; set; }
        LaunchOptionTile amd_anti_lag_tile { get; set; }
        LaunchOptionTile amd_prime_tile { get; set; }
        LaunchOptionTile amd_hide_apu_tile { get; set; }
        LaunchOptionTile amd_staging_shared_memory_tile { get; set; }
        LaunchOptionTile amd_mesa_glthread_tile { get; set; }
        LaunchOptionTile amd_mesa_shader_cache_disable_tile { get; set; }
        LaunchOptionTile nvapi_tile { get; set; }
        LaunchOptionTile nvidia_ngx_updater_tile { get; set; }
        LaunchOptionTile nvidia_hide_gpu_tile { get; set; }
        LaunchOptionTile dlss_indicator_tile { get; set; }
        LaunchOptionTile nvidia_libs_tile { get; set; }
        LaunchOptionTile intel_xess_upgrade_tile { get; set; }
        LaunchOptionTile prefer_sdl_tile { get; set; }
        LaunchOptionTile no_steaminput_tile { get; set; }
        LaunchOptionTile ntsync_tile { get; set; }
        LaunchOptionTile wine_vk_use_sync2_tile { get; set; }
        LaunchOptionTile wine_sync_use_futex_waitv_tile { get; set; }
        LaunchOptionTile wine_writecopy_tile { get; set; }
        LaunchOptionTile proton_priority_high_tile { get; set; }
        LaunchOptionTile proton_use_wow64_tile { get; set; }
        LaunchOptionTile proton_force_large_address_aware_tile { get; set; }
        LaunchOptionTile proton_logs_tile { get; set; }
        LaunchOptionSpinTile pulse_latency_tile { get; set; }
        LaunchOptionTile local_shader_cache_tile { get; set; }
        LaunchOptionEntryField additional_args_field { get; set; }
        LaunchOptionTile additional_args_tile { get; set; }
        LaunchOptionTile command_tile { get; set; }
        LaunchOptionTile skip_launcher_tile { get; set; }
        LaunchOptionTile vulkan_tile { get; set; }
        LaunchOptionTile dx11_tile { get; set; }
        LaunchOptionTile dx12_tile { get; set; }
        LaunchOptionTile console_tile { get; set; }
        LaunchOptionPreviewField preview_field { get; set; }
        Gtk.Stack wrapper_stack { get; set; }
        Gtk.StackSwitcher wrapper_switcher { get; set; }
        Gtk.Stack gpu_vendor_stack { get; set; }
        Gtk.StackSwitcher gpu_vendor_switcher { get; set; }
        LaunchOptionTile gamescope_fullscreen_tile { get; set; }
        LaunchOptionTile gamescope_hdr_tile { get; set; }
        LaunchOptionTile gamescope_vrr_tile { get; set; }
        LaunchOptionSpinTile gamescope_framerate_tile { get; set; }
        LaunchOptionResolutionField gamescope_resolution_field { get; set; }
        LaunchOptionEntryField gamescope_args_field { get; set; }
        LaunchOptionTile scopebuddy_fullscreen_tile { get; set; }
        LaunchOptionTile scopebuddy_auto_hdr_tile { get; set; }
        LaunchOptionTile scopebuddy_auto_vrr_tile { get; set; }
        LaunchOptionSpinTile scopebuddy_framerate_tile { get; set; }
        LaunchOptionResolutionField scopebuddy_resolution_field { get; set; }
        LaunchOptionEntryField scopebuddy_args_field { get; set; }
        LaunchOptionDllOverrides dll_overrides_pair_editor { get; set; }
        LaunchOptionAmdIcd amd_icd_editor { get; set; }
        LaunchOptionRadvPerftest radv_perf_editor { get; set; }
        LaunchOptionRadvDebug radv_debug_editor { get; set; }
        Groups.DxvkOptionsGroup dxvk_options_group { get; set; }
        Groups.Vkd3dOptionsGroup vkd3d_options_group;
        List<LaunchOptionBinding> common_bindings;
        List<LaunchOptionBinding> gpu_vendor_bindings;
        List<LaunchOptionBinding> game_argument_bindings;
        List<LaunchOptionBinding> scopebuddy_bindings;
        List<ILaunchOption> launch_option_handlers;
        bool advanced_visible;
        bool refreshing_controls;
        bool can_auto_enable_command;

        construct {
            common_bindings = new List<LaunchOptionBinding> ();
            gpu_vendor_bindings = new List<LaunchOptionBinding> ();
            game_argument_bindings = new List<LaunchOptionBinding> ();
            scopebuddy_bindings = new List<LaunchOptionBinding> ();
            launch_option_handlers = new List<ILaunchOption> ();
            advanced_visible = false;
            can_auto_enable_command = true;
            refreshing_controls = true;

            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (15);

        // Launch command preview

            preview_field = new LaunchOptionPreviewField (_ ("Launch command preview"));
            append (preview_field);

        // Common options
            var common_group = new Groups.CommonOptionsGroup (standard_control_changed, launch_option_handlers);
            append (common_group);

            // Launch tools

            hdr_tile = new LaunchOptionTile (_ ("HDR"), _ ("Outputs HDR colors if your display supports it."));
            hdr_tile.toggle.notify["active"].connect (standard_control_changed);

            wrapper_stack = new Gtk.Stack ();
            wrapper_stack.set_hhomogeneous (false);
            wrapper_stack.set_vhomogeneous (false);
            wrapper_stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
            wrapper_stack.notify["visible-child-name"].connect (wrapper_selection_changed);
            var none_page = create_none_page ();
            var gamescope_page = create_gamescope_page ();
            var scopebuddy_page = create_scopebuddy_page ();

            wrapper_stack.add_titled (none_page, "none", _ ("None"));

            if (Globals.GAMESCOPE_INSTALLED)
            wrapper_stack.add_titled (gamescope_page, "gamescope", _ ("Gamescope"));
            else
            wrapper_stack.add_named (gamescope_page, "gamescope");

            if (Globals.SCOPEBUDDY_INSTALLED)
            wrapper_stack.add_titled (scopebuddy_page, "scopebuddy", _ ("ScopeBuddy"));
            else
            wrapper_stack.add_named (scopebuddy_page, "scopebuddy");

            wrapper_switcher = new Gtk.StackSwitcher ();
            wrapper_switcher.set_stack (wrapper_stack);
            wrapper_switcher.set_halign (Gtk.Align.START);

            if (!Globals.GAMESCOPE_INSTALLED && !Globals.SCOPEBUDDY_INSTALLED)
            wrapper_switcher.visible = false;

            var wrapper_group = new Adw.PreferencesGroup ();
            wrapper_group.title = _ ("Launch tools");
            wrapper_group.description = _ ("Choose one to configure FPS caps, resolution, and other display options.");
            wrapper_group.set_header_suffix (wrapper_switcher);
            wrapper_group.add (wrapper_stack);

            append (wrapper_group);

            // GPU vendor options

            amd_anti_lag_tile = create_gpu_vendor_tile (_ ("Mesa Anti-Lag"), _ ("Reduces latency on supported AMD Mesa setups."), { "ENABLE_LAYER_MESA_ANTI_LAG=1" });
            amd_prime_tile = create_gpu_vendor_tile (_ ("Use dGPU"), _ ("Makes the game use the AMD dGPU on hybrid systems."), { "DRI_PRIME=1" });
            amd_hide_apu_tile = create_gpu_vendor_tile (_ ("Hide AMD APU"), _ ("Makes Proton report an AMD APU as a discrete GPU for games that mis-detect integrated graphics."), { "PROTON_HIDE_APU=1" });
            amd_fsr4_upgrade_tile = new LaunchOptionTile (_ ("FSR 4 Upgrade"), _ ("Upgrades FSR 3.1 to FSR 4 in supported games. This option also disables AMD Anti-Lag 2 currently due to various issues."));
            amd_fsr4_upgrade_tile.toggle.notify["active"].connect (amd_fsr4_upgrade_toggle_changed);
            gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_FSR4_UPGRADE=1" }, amd_fsr4_upgrade_tile.toggle));

            amd_fsr4_rdna3_upgrade_tile = new LaunchOptionTile (_ ("FSR 4 RDNA3 Upgrade"), _ ("Optimizes FSR 4.0 for RDNA3 hardware."));
            amd_fsr4_rdna3_upgrade_tile.toggle.notify["active"].connect (amd_fsr4_rdna3_upgrade_toggle_changed);
            gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_FSR4_RDNA3_UPGRADE=1" }, amd_fsr4_rdna3_upgrade_tile.toggle));

            amd_staging_shared_memory_tile = create_gpu_vendor_tile (_ ("Staging shared memory"), _ ("Enables shared memory support in the AMD GPU driver for better performance in some games."), { "STAGING_SHARED_MEMORY=1" });
            amd_mesa_glthread_tile = create_gpu_vendor_tile (_ ("Mesa GLThread"), _ ("Enables Mesa's GLThread optimization for better performance in some games."), { "mesa_glthread=true" });
            amd_mesa_shader_cache_disable_tile = create_gpu_vendor_tile (_ ("Disable Mesa shader cache"), _ ("Disables Mesa's shader cache which can cause stuttering in some games."), { "MESA_SHADER_CACHE_DISABLE=1" });


            nvapi_tile = new LaunchOptionTile (_ ("NVAPI"), _ ("Lets games access NVIDIA-specific features like DLSS."));
            nvapi_tile.toggle.notify["active"].connect (nvidia_nvapi_toggle_changed);
            gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_ENABLE_NVAPI=1" }, nvapi_tile.toggle));
            nvidia_ngx_updater_tile = new LaunchOptionTile (_ ("Update DLSS components"), _ ("Auto upgrades DLSS components for supported games."));
            nvidia_ngx_updater_tile.toggle.notify["active"].connect (nvidia_dlss_updater_toggle_changed);
            gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_ENABLE_NGX_UPDATER=1" }, nvidia_ngx_updater_tile.toggle));
            nvidia_hide_gpu_tile = create_gpu_vendor_tile (_ ("Hide NVIDIA GPU"), _ ("Makes Proton report an NVIDIA GPU as AMD for games that expect Windows-only NVIDIA driver behavior."), { "PROTON_HIDE_NVIDIA_GPU=1" });
            dlss_indicator_tile = create_gpu_vendor_tile (_ ("DLSS Indicator"), _ ("Shows a DLSS status indicator in-game."), { "PROTON_DLSS_INDICATOR=1" });
            nvidia_libs_tile = create_gpu_vendor_tile (_ ("NVIDIA Libraries"), _ ("Enables NVIDIA-specific libraries (PhysX, CUDA). This is not needed for DLSS or ray tracing."), { "PROTON_NVIDIA_LIBS=1" });

            intel_xess_upgrade_tile = create_gpu_vendor_tile (_ ("XeSS Upgrade"), _ ("Upgrades XeSS in supported games."), { "PROTON_XESS_UPGRADE=1" });

            // AMD
            radv_debug_editor = new LaunchOptionRadvDebug ();
            radv_perf_editor = new LaunchOptionRadvPerftest ();
            amd_icd_editor = new LaunchOptionAmdIcd ();
            launch_option_handlers.append (radv_debug_editor);
            launch_option_handlers.append (radv_perf_editor);
            launch_option_handlers.append (amd_icd_editor);

            radv_debug_editor.changed.connect (standard_control_changed);
            radv_perf_editor.changed.connect (standard_control_changed);
            amd_icd_editor.changed.connect (standard_control_changed);
            radv_debug_editor.set_tooltip_text (_ ("Configure RADV debug options for troubleshooting and performance testing."));
            radv_perf_editor.set_tooltip_text (_ ("Configure RADV performance test options for testing experimental driver features. Use with caution as these features can cause instability or other issues."));
            amd_icd_editor.set_tooltip_text (_ ("Select which AMD Vulkan driver to use. This can be used to switch between RADV and AMD's official Vulkan driver on supported systems."));

            Adw.PreferencesGroup gpu_vendor_amd_group = create_gpu_vendor_page ({ amd_anti_lag_tile, amd_fsr4_upgrade_tile, amd_fsr4_rdna3_upgrade_tile, amd_prime_tile, amd_hide_apu_tile, amd_staging_shared_memory_tile, amd_mesa_glthread_tile, amd_mesa_shader_cache_disable_tile });

            gpu_vendor_amd_group.add (radv_debug_editor);
            gpu_vendor_amd_group.add (radv_perf_editor);
            gpu_vendor_amd_group.add (amd_icd_editor);

            gpu_vendor_stack = new Gtk.Stack ();
            gpu_vendor_stack.set_hhomogeneous (false);
            gpu_vendor_stack.set_vhomogeneous (false);
            gpu_vendor_stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
            gpu_vendor_stack.add_titled (gpu_vendor_amd_group, "amd", _ ("AMD"));
            gpu_vendor_stack.add_titled (create_gpu_vendor_page ({ nvapi_tile, nvidia_ngx_updater_tile, nvidia_hide_gpu_tile, dlss_indicator_tile, nvidia_libs_tile }), "nvidia", _ ("NVIDIA"));
            gpu_vendor_stack.add_titled (create_gpu_vendor_page ({ intel_xess_upgrade_tile }), "intel", _ ("Intel"));
            gpu_vendor_stack.set_visible_child_name ("amd");

            gpu_vendor_switcher = new Gtk.StackSwitcher ();
            gpu_vendor_switcher.set_stack (gpu_vendor_stack);
            gpu_vendor_switcher.set_halign (Gtk.Align.START);

            gpu_vendor_stack.notify["visible-child-name"].connect (gpu_vendor_selection_changed);

            gpu_vendor_group = new Adw.PreferencesGroup ();
            gpu_vendor_group.title = _ ("GPU vendor options");
            gpu_vendor_group.description = _ ("Use GPU-specific compatibility toggles for AMD, NVIDIA and Intel hardware.");
            gpu_vendor_group.set_header_suffix (gpu_vendor_switcher);
            gpu_vendor_group.add (gpu_vendor_stack);
            append (gpu_vendor_group);

            //  DXVK options
            dxvk_options_group = new Groups.DxvkOptionsGroup (standard_control_changed, launch_option_handlers);
            append (dxvk_options_group);

            //  VKD3D options
            vkd3d_options_group = new Groups.Vkd3dOptionsGroup (standard_control_changed, launch_option_handlers);
            append (vkd3d_options_group);

            // More options

            vkbasalt_tile = create_common_tile (_ ("VKBasalt"), _ ("Adds visual effects like sharpening and color adjustments."), { "ENABLE_VKBASALT=1" });
            wined3d_tile = create_common_tile (_ ("WineD3D"), _ ("Uses OpenGL instead of Vulkan. Only enable if you're having DXVK issues."), { "PROTON_USE_WINED3D=1" });
            ntsync_tile = create_common_tile (_ ("Use FSync"), _ ("Uses FSync instead of NTSync. Can fix issues in certain games that do not pair well with NTSync."), { "PROTON_USE_NTSYNC=0" });
            local_shader_cache_tile = create_common_tile (_ ("Local shader cache"), _ ("Enables per-game shader cache. This isolates the shader cache of each game but does not compile them ahead-of-time."), { "PROTON_LOCAL_SHADER_CACHE=1" });
            prefer_sdl_tile = create_common_tile (_ ("Prefer SDL controller"), _ ("Workaround for controller detection issues."), { "PROTON_PREFER_SDL=1" });
            no_steaminput_tile = create_common_tile (_ ("Disable Steam Input"), _ ("Disables Steam Input support. Fixes Wayland controller/gamepad issues."), { "PROTON_NO_STEAMINPUT=1" });
            wine_vk_use_sync2_tile = create_common_tile (_ ("WINE_VK_USE_SYNC2"), _ ("Enables WINE_VK_USE_SYNC2 which can improve performance and reduce stuttering in some games when using WineD3D."), { "WINE_VK_USE_SYNC2=1" });
            wine_sync_use_futex_waitv_tile = create_common_tile (_ ("WINE_SYNC_USE_FUTEX_WAITV"), _ ("Enables WINE_SYNC_USE_FUTEX_WAITV which can improve performance and reduce stuttering in some games when using WineD3D."), { "WINE_SYNC_USE_FUTEX_WAITV=1" });
            wine_writecopy_tile = create_common_tile (_ ("Simulate Write-Copy Memory"), _ ("Forces Wine to simulate page-write protection, fixing initialization errors in certain older titles."), { "WINE_SIMULATE_WRITECOPY=1" });

            more_options_group = new Adw.PreferencesGroup ();
            more_options_group.title = _ ("More options");
            more_options_group.description = _ ("Extra graphics settings and launch behaviors.");
            more_options_group.add (vkbasalt_tile);
            more_options_group.add (wined3d_tile);
            more_options_group.add (ntsync_tile);
            more_options_group.add (local_shader_cache_tile);
            more_options_group.add (prefer_sdl_tile);
            more_options_group.add (no_steaminput_tile);
            more_options_group.add (wine_vk_use_sync2_tile);
            more_options_group.add (wine_sync_use_futex_waitv_tile);
            more_options_group.add (wine_writecopy_tile);
            append (more_options_group);

            // Proton options

            proton_priority_high_tile = create_common_tile (_ ("Higher priority for games"), _ ("Gives the game a higher CPU priority which can improve performance in some cases."), { "PROTON_PRIORITY_HIGH=1" });
            proton_use_wow64_tile = create_common_tile (_ ("Use WoW64"), _ ("Enables WoW64 support for 32-bit games on 64-bit Proton builds. This can improve compatibility for some older games."), { "PROTON_USE_WOW64=1" });
            proton_force_large_address_aware_tile = create_common_tile (_ ("Allows 32-bit games to use more than 2GB of RAM"), _ ("Forces 32-bit games to use large address aware which can improve performance and stability."), { "PROTON_FORCE_LARGE_ADDRESS_AWARE=1" });
            proton_logs_tile = create_common_tile (_ ("Enable Proton logs"), _ ("Enables logging for Proton which can help with troubleshooting game issues. Logs are saved in the game's compatibility data folder."), { "PROTON_LOG=1" });

            // DLL overrides
            dll_overrides_pair_editor = new LaunchOptionDllOverrides ();
            dll_overrides_pair_editor.changed.connect (standard_control_changed);
            launch_option_handlers.append (dll_overrides_pair_editor);

            proton_options_group = new Adw.PreferencesGroup ();
            proton_options_group.title = _ ("Proton options");
            proton_options_group.description = _ ("Extra Proton settings and launch behaviors.");
            proton_options_group.add (proton_priority_high_tile);
            proton_options_group.add (proton_use_wow64_tile);
            proton_options_group.add (proton_force_large_address_aware_tile);
            proton_options_group.add (proton_logs_tile);
            proton_options_group.add (dll_overrides_pair_editor);
            append (proton_options_group);

            // Audio options

            pulse_latency_tile = new LaunchOptionSpinTile (_ ("PulseAudio low latency"), _ ("Enables low latency mode in PulseAudio which can reduce audio latency in some games (60, 90, 120)."), _ ("MSEC"), 30, 360, 90);
            pulse_latency_tile.toggle.notify["active"].connect (standard_control_changed);
            pulse_latency_tile.value_applied.connect (standard_control_changed);

            var audio_group = new Adw.PreferencesGroup ();
            audio_group.title = _ ("Audio options");
            audio_group.description = _ ("Audio-related launch options.");
            audio_group.add (pulse_latency_tile);

            append (audio_group);
            // Game arguments

            skip_launcher_tile = create_game_argument_tile (_ ("Skip launcher"), _ ("Adds -skip-launcher to bypass launchers in games that support it."), { "-skip-launcher" });
            vulkan_tile = create_game_argument_tile (_ ("Vulkan"), _ ("Adds -vulkan to make the game use its Vulkan renderer."), { "-vulkan" });
            dx11_tile = create_game_argument_tile (_ ("DirectX 11"), _ ("Adds -dx11 to make the game use its DirectX 11 renderer."), { "-dx11" });
            dx12_tile = create_game_argument_tile (_ ("DirectX 12"), _ ("Adds -dx12 to make the game use its DirectX 12 renderer."), { "-dx12" });
            console_tile = create_game_argument_tile (_ ("Console"), _ ("Adds -console to open the game's developer console when supported."), { "-console" });

            game_arguments_group = new Adw.PreferencesGroup ();
            game_arguments_group.title = _ ("Game arguments");
            game_arguments_group.description = _ ("Flags passed directly to the game.");
            game_arguments_group.add (skip_launcher_tile);
            game_arguments_group.add (vulkan_tile);
            game_arguments_group.add (dx11_tile);
            game_arguments_group.add (dx12_tile);
            game_arguments_group.add (console_tile);
            append (game_arguments_group);

            // Advanced options

            command_tile = new LaunchOptionTile ("%command%", _ ("Appends Steam's game command."));
            command_tile.toggle.notify["active"].connect (command_toggle_changed);

            additional_args_field = new LaunchOptionEntryField (_ ("Additional arguments"), "", _ ("Add extra launch options"));
            additional_args_field.value_applied.connect (standard_control_changed);

            additional_args_tile = new LaunchOptionTile (_ ("Custom launch arguments"), _ ("Add your own launch options."));
            additional_args_tile.toggle.notify["active"].connect (additional_args_toggle_changed);

            advanced_options_group = new Adw.PreferencesGroup ();
            advanced_options_group.set_margin_bottom (15);
            advanced_options_group.title = _ ("Advanced options");
            advanced_options_group.description = _ ("Extra control over the final Steam launch command.");
            advanced_options_group.add (command_tile);
            advanced_options_group.add (additional_args_tile);
            advanced_options_group.add (additional_args_field);
            append (advanced_options_group);


            foreach (var binding in common_bindings) {
                launch_option_handlers.append (binding);
            }
            foreach (var binding in gpu_vendor_bindings) {
                launch_option_handlers.append (binding);
            }
            foreach (var binding in game_argument_bindings) {
                launch_option_handlers.append (binding);
            }
            foreach (var binding in scopebuddy_bindings) {
                launch_option_handlers.append (binding);
            }

            set_selected_wrapper_mode (WrapperMode.NONE);
            refresh_advanced_visibility ();
            refreshing_controls = false;
            refresh_preview ();
        }

        public bool get_advanced_visible () {
            return advanced_visible;
        }

        public void set_advanced_visible (bool visible) {
            advanced_visible = visible;
            refresh_advanced_visibility ();
        }

        public void clear () {
            var keep_advanced_visible = advanced_visible;
            set_text ("");
            set_advanced_visible (keep_advanced_visible);
        }

        public bool has_clearable_state () {
            if (hdr_tile.toggle.get_active ())
            return true;

            foreach (var binding in common_bindings) {
                if (binding.toggle.get_active ())
                return true;
            }

            foreach (var binding in gpu_vendor_bindings) {
                if (binding.toggle.get_active ())
                return true;
            }

            foreach (var binding in game_argument_bindings) {
                if (binding.toggle.get_active ())
                return true;
            }

            foreach (var binding in scopebuddy_bindings) {
                if (binding.toggle.get_active ())
                return true;
            }

            if (get_selected_wrapper_mode () != WrapperMode.NONE)
            return true;

            if (gamescope_fullscreen_tile.toggle.get_active ()
            || gamescope_hdr_tile.toggle.get_active ()
            || gamescope_vrr_tile.toggle.get_active ()
            || gamescope_framerate_tile.toggle.get_active ()
            || gamescope_resolution_field.toggle.get_active ()
            || gamescope_args_field.get_text () != "")
            return true;

            if (scopebuddy_fullscreen_tile.toggle.get_active ()
            || scopebuddy_framerate_tile.toggle.get_active ()
            || scopebuddy_resolution_field.toggle.get_active ()
            || scopebuddy_args_field.get_text () != "")
            return true;

            if (additional_args_tile.toggle.get_active ()
            || additional_args_field.get_text () != ""
            || command_tile.toggle.get_active ())
            return true;

            return false;
        }

        public string get_text () {
            var output = new StringBuilder ();
            var command_segments = get_command_segments ();

            if (command_segments.size == 0)
            return "";

            foreach (var segment in command_segments) {
                if (output.len > 0)
                output.append (" ");

                output.append (segment);
            }

            return output.str;
        }

        public void set_text (string launch_options) {
            var tokens = get_launch_option_tokens (launch_options);
            var consumed = new bool[tokens.length];
            var selected_wrapper_mode = detect_wrapper_mode (tokens);
            refreshing_controls = true;

            reset_controls ();

            foreach (var editor in launch_option_handlers) {
                editor.parse_tokens (tokens, consumed);
            }

            if (selected_wrapper_mode == WrapperMode.NONE)
            parse_none_tokens (tokens, consumed);
                else if (selected_wrapper_mode == WrapperMode.GAMESCOPE)
                parse_gamescope_tokens (tokens, consumed);
                else if (selected_wrapper_mode == WrapperMode.SCOPEBUDDY)
                parse_scopebuddy_tokens (tokens, consumed);

                normalize_nvidia_vendor_dependencies ();
                normalize_amd_fsr_upgrade_dependencies ();

                var command_index = get_token_index (tokens, "%command%");
                apply_game_argument_bindings_from_tokens (tokens, consumed, command_index);
                command_tile.toggle.set_active (command_index >= 0);
                if (command_index >= 0)
                consumed[command_index] = true;

                set_selected_wrapper_mode (selected_wrapper_mode);
                var additional_args = join_unconsumed_tokens (tokens, consumed);
                additional_args_field.set_text (additional_args);
                additional_args_tile.toggle.set_active (additional_args != "");
                select_preferred_gpu_vendor_page ();
                advanced_visible = should_show_advanced_controls ();
                refresh_advanced_visibility ();

                can_auto_enable_command = command_index < 0;
                refreshing_controls = false;
                maybe_auto_enable_command ();
                refresh_preview ();
        }

        LaunchOptionTile create_common_tile (string title, string subtitle, string[] tokens) {
            var tile = new LaunchOptionTile (title, subtitle);
            tile.toggle.notify["active"].connect (standard_control_changed);

            common_bindings.append (new LaunchOptionBinding (tokens, tile.toggle));

            return tile;
        }

        LaunchOptionTile create_gpu_vendor_tile (string title, string subtitle, string[] tokens) {
            var tile = new LaunchOptionTile (title, subtitle);
            tile.toggle.notify["active"].connect (standard_control_changed);

            gpu_vendor_bindings.append (new LaunchOptionBinding (tokens, tile.toggle));

            return tile;
        }

        LaunchOptionTile create_game_argument_tile (string title, string subtitle, string[] tokens) {
            var tile = new LaunchOptionTile (title, subtitle);
            tile.toggle.notify["active"].connect (standard_control_changed);

            game_argument_bindings.append (new LaunchOptionBinding (tokens, tile.toggle));

            return tile;
        }

        Gtk.Widget create_none_page () {
            var group = new Adw.PreferencesGroup ();
            group.add (hdr_tile);
            return group;
        }

        Adw.PreferencesGroup create_gpu_vendor_page (LaunchOptionTile[] tiles) {
            var group = new Adw.PreferencesGroup ();
            for (var index = 0; index < tiles.length; index++) {
                group.add (tiles[index]);
            }
            return group;
        }

        Gtk.Widget create_gamescope_page () {
            var group = new Adw.PreferencesGroup ();

            gamescope_fullscreen_tile = new LaunchOptionTile (_ ("Fullscreen"), _ ("Runs the game in a fullscreen session."));
            gamescope_fullscreen_tile.toggle.notify["active"].connect (standard_control_changed);

            gamescope_hdr_tile = new LaunchOptionTile (_ ("HDR"), _ ("Outputs HDR colors if your display supports it."));
            gamescope_hdr_tile.toggle.notify["active"].connect (standard_control_changed);

            gamescope_vrr_tile = new LaunchOptionTile (_ ("VRR"), _ ("Matches your display's refresh rate to the game's FPS."));
            gamescope_vrr_tile.toggle.notify["active"].connect (standard_control_changed);

            gamescope_framerate_tile = new LaunchOptionSpinTile (_ ("Frame limit"), _ ("Caps the frame rate inside Gamescope."), _ ("FPS"), 30, 360, 60);
            gamescope_framerate_tile.toggle.notify["active"].connect (standard_control_changed);
            gamescope_framerate_tile.value_applied.connect (standard_control_changed);

            gamescope_resolution_field = new LaunchOptionResolutionField (_ ("Resolution"), _ ("Sets the Gamescope output resolution."), false, false);
            gamescope_resolution_field.toggle.notify["active"].connect (standard_control_changed);
            gamescope_resolution_field.dropdown.notify["selected"].connect (standard_control_changed);
            gamescope_resolution_field.value_applied.connect (standard_control_changed);

            launch_option_handlers.append (gamescope_resolution_field);

            group.add (gamescope_fullscreen_tile);
            group.add (gamescope_hdr_tile);
            group.add (gamescope_vrr_tile);
            group.add (gamescope_framerate_tile);
            group.add (gamescope_resolution_field);

            gamescope_args_field = new LaunchOptionEntryField (_ ("Additional Gamescope arguments"), _ ("Keeps extra Gamescope flags such as output or resolution tweaks."), _ ("Add Gamescope arguments"));
            gamescope_args_field.value_applied.connect (standard_control_changed);

            group.add (gamescope_args_field);

            return group;
        }

        Gtk.Widget create_scopebuddy_page () {
            var group = new Adw.PreferencesGroup ();

            scopebuddy_fullscreen_tile = new LaunchOptionTile (_ ("Fullscreen"), _ ("Runs the game in a fullscreen session."));
            scopebuddy_fullscreen_tile.toggle.notify["active"].connect (standard_control_changed);

            scopebuddy_auto_hdr_tile = new LaunchOptionTile (_ ("Auto HDR"), _ ("Outputs HDR colors if your display supports it."));
            scopebuddy_auto_hdr_tile.toggle.notify["active"].connect (standard_control_changed);

            scopebuddy_auto_vrr_tile = new LaunchOptionTile (_ ("VRR"), _ ("Matches your display's refresh rate to the game's FPS."));
            scopebuddy_auto_vrr_tile.toggle.notify["active"].connect (standard_control_changed);

            scopebuddy_framerate_tile = new LaunchOptionSpinTile (_ ("Frame limit"), _ ("Caps the frame rate inside ScopeBuddy."), _ ("FPS"), 30, 360, 60);
            scopebuddy_framerate_tile.toggle.notify["active"].connect (standard_control_changed);
            scopebuddy_framerate_tile.value_applied.connect (standard_control_changed);

            scopebuddy_bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_HDR=1" }, scopebuddy_auto_hdr_tile.toggle));
            scopebuddy_bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_VRR=1" }, scopebuddy_auto_vrr_tile.toggle));

            scopebuddy_resolution_field = new LaunchOptionResolutionField (_ ("Resolution"), _ ("Sets the ScopeBuddy output resolution."), true, true);
            scopebuddy_resolution_field.toggle.notify["active"].connect (standard_control_changed);
            scopebuddy_resolution_field.dropdown.notify["selected"].connect (standard_control_changed);
            scopebuddy_resolution_field.value_applied.connect (standard_control_changed);
            launch_option_handlers.append (scopebuddy_resolution_field);

            scopebuddy_args_field = new LaunchOptionEntryField (_ ("Additional ScopeBuddy arguments"), _ ("Keeps extra ScopeBuddy flags such as preferred output selection."), _ ("Add ScopeBuddy arguments"));
            scopebuddy_args_field.value_applied.connect (standard_control_changed);

            group.add (scopebuddy_fullscreen_tile);
            group.add (scopebuddy_auto_hdr_tile);
            group.add (scopebuddy_auto_vrr_tile);
            group.add (scopebuddy_framerate_tile);
            group.add (scopebuddy_resolution_field);
            group.add (scopebuddy_args_field);

            return group;
        }

        void reset_controls () {
            gamescope_fullscreen_tile.toggle.set_active (false);
            gamescope_hdr_tile.toggle.set_active (false);
            gamescope_vrr_tile.toggle.set_active (false);
            gamescope_framerate_tile.toggle.set_active (false);
            gamescope_framerate_tile.set_value (60);
            scopebuddy_fullscreen_tile.toggle.set_active (false);
            scopebuddy_framerate_tile.toggle.set_active (false);
            scopebuddy_framerate_tile.set_value (60);
            additional_args_tile.toggle.set_active (false);
            command_tile.toggle.set_active (false);
            hdr_tile.toggle.set_active (false);

            additional_args_field.set_text ("");
            gamescope_args_field.set_text ("");
            scopebuddy_args_field.set_text ("");
            gpu_vendor_stack.set_visible_child_name ("amd");

            foreach (var editor in launch_option_handlers) {
                editor.clear ();
            }
        }

        void standard_control_changed () {
            if (refreshing_controls)
            return;

            maybe_auto_enable_command ();
            refresh_preview ();
            content_changed ();
        }

        void refresh_advanced_visibility () {
            var is_advanced = advanced_visible;
            preview_field.set_visible (is_advanced);
            more_options_group.set_visible (is_advanced);
            proton_options_group.set_visible (is_advanced);
            gpu_vendor_group.set_visible (is_advanced);
            game_arguments_group.set_visible (is_advanced);
            gamescope_args_field.set_visible (is_advanced);
            scopebuddy_args_field.set_visible (is_advanced);
            advanced_options_group.set_visible (is_advanced);
            additional_args_field.set_visible (is_advanced && additional_args_tile.toggle.get_active ());
            wrapper_stack.set_visible (true);
        }

        void additional_args_toggle_changed () {
            if (refreshing_controls)
            return;

            refresh_advanced_visibility ();
            if (additional_args_tile.toggle.get_active ())
            additional_args_field.focus_entry ();
            maybe_auto_enable_command ();
            refresh_preview ();
            content_changed ();
        }

        void command_toggle_changed () {
            if (refreshing_controls)
            return;

            if (!command_tile.toggle.get_active () && has_active_binding (game_argument_bindings)) {
                refreshing_controls = true;
                reset_binding_toggles (game_argument_bindings);
                refreshing_controls = false;
            }

            can_auto_enable_command = false;
            refresh_preview ();
            content_changed ();
        }

        void wrapper_selection_changed () {
            if (refreshing_controls)
            return;

            refreshing_controls = true;

            var current_wrapper = wrapper_stack.get_visible_child_name ();

            if (current_wrapper != "none") {
                hdr_tile.toggle.set_active (false);
            }

            if (current_wrapper != "gamescope") {
                gamescope_fullscreen_tile.toggle.set_active (false);
                gamescope_hdr_tile.toggle.set_active (false);
                gamescope_vrr_tile.toggle.set_active (false);
                gamescope_framerate_tile.toggle.set_active (false);
                gamescope_framerate_tile.set_value (60);
                gamescope_resolution_field.reset ();
                gamescope_args_field.set_text ("");
            }

            if (current_wrapper != "scopebuddy") {
                scopebuddy_fullscreen_tile.toggle.set_active (false);
                scopebuddy_framerate_tile.toggle.set_active (false);
                scopebuddy_framerate_tile.set_value (60);
                scopebuddy_resolution_field.reset ();
                scopebuddy_args_field.set_text ("");
                foreach (var binding in scopebuddy_bindings) {
                    binding.toggle.set_active (false);
                }
            }

            refreshing_controls = false;

            refresh_advanced_visibility ();
            maybe_auto_enable_command ();
            refresh_preview ();
            content_changed ();
        }

        void gpu_vendor_selection_changed () {
            if (refreshing_controls)
            return;

            refreshing_controls = true;

            var current_vendor = gpu_vendor_stack.get_visible_child_name ();

            if (current_vendor != "amd") {
                amd_anti_lag_tile.toggle.set_active (false);
                amd_fsr4_upgrade_tile.toggle.set_active (false);
                amd_fsr4_rdna3_upgrade_tile.toggle.set_active (false);
                amd_prime_tile.toggle.set_active (false);
                amd_hide_apu_tile.toggle.set_active (false);
            }

            if (current_vendor != "nvidia") {
                nvapi_tile.toggle.set_active (false);
                nvidia_ngx_updater_tile.toggle.set_active (false);
                nvidia_hide_gpu_tile.toggle.set_active (false);
                dlss_indicator_tile.toggle.set_active (false);
                nvidia_libs_tile.toggle.set_active (false);
            }

            if (current_vendor != "intel") {
                intel_xess_upgrade_tile.toggle.set_active (false);
            }

            refreshing_controls = false;

            refresh_preview ();
            content_changed ();
        }

        bool should_show_advanced_controls () {
            return vkbasalt_tile.toggle.get_active ()
            || wined3d_tile.toggle.get_active ()
            || ntsync_tile.toggle.get_active ()
            || local_shader_cache_tile.toggle.get_active ()
            || has_active_binding (gpu_vendor_bindings)
            || has_active_binding (game_argument_bindings)
            || additional_args_tile.toggle.get_active ()
            || additional_args_field.get_text () != ""
            || gamescope_args_field.get_text () != ""
            || scopebuddy_args_field.get_text () != "";
        }

        void maybe_auto_enable_command () {
            if (command_tile.toggle.get_active () && !has_structured_content ()) {
                refreshing_controls = true;
                command_tile.toggle.set_active (false);
                refreshing_controls = false;

                can_auto_enable_command = true;
            }

            if (!can_auto_enable_command || command_tile.toggle.get_active () || !has_structured_content ())
            return;

            refreshing_controls = true;
            command_tile.toggle.set_active (true);
            refreshing_controls = false;

            can_auto_enable_command = false;
        }

        bool has_structured_content () {
            var segments = get_command_segments ();
            if (segments.size > 0) {
                return true;
            }

            if (additional_args_tile.toggle.get_active () && additional_args_field.get_text () != "")
            return true;

            switch (get_selected_wrapper_mode ()) {
                case WrapperMode.NONE:
                    if (hdr_tile.toggle.get_active ())
                    return true;

                    return false;
                case WrapperMode.GAMESCOPE:
                case WrapperMode.SCOPEBUDDY:
                    return true;
                default:
                    return false;
            }
        }

        Gee.LinkedList<string> get_command_segments () {
            var segments = new Gee.LinkedList<string> ();
            var selected_wrapper_mode = get_selected_wrapper_mode ();

            foreach (var editor in launch_option_handlers) {
                if (editor == gamescope_resolution_field || editor == scopebuddy_resolution_field) {
                    continue;
                }
                editor.append_command_segments (segments);
            }

            if (additional_args_tile.toggle.get_active ())
            append_segments_from_text (segments, additional_args_field.get_text ());

            switch (selected_wrapper_mode) {
                case WrapperMode.NONE:
                    append_none_segments (segments);
                    break;
                case WrapperMode.GAMESCOPE:
                    segments.add ("gamescope");

                    gamescope_resolution_field.append_command_segments (segments);

                    if (gamescope_fullscreen_tile.toggle.get_active ())
                    segments.add ("-f");

                    if (gamescope_hdr_tile.toggle.get_active ())
                    segments.add ("--hdr-enabled");

                    if (gamescope_vrr_tile.toggle.get_active ())
                    segments.add ("--adaptive-sync");

                    if (gamescope_framerate_tile.toggle.get_active ())
                    segments.add ("-r %d".printf (gamescope_framerate_tile.get_value_as_int ()));

                    append_segments_from_text (segments, gamescope_args_field.get_text ());
                    break;
                case WrapperMode.SCOPEBUDDY:
                    if (scopebuddy_resolution_field.is_auto ()) {
                        scopebuddy_resolution_field.append_command_segments (segments);
                    }

                    segments.add ("scopebuddy");

                    if (!scopebuddy_resolution_field.is_auto ()) {
                        scopebuddy_resolution_field.append_command_segments (segments);
                    }

                    if (scopebuddy_fullscreen_tile.toggle.get_active ())
                    segments.add ("-f");

                    if (scopebuddy_framerate_tile.toggle.get_active ())
                    segments.add ("-r %d".printf (scopebuddy_framerate_tile.get_value_as_int ()));

                    append_segments_from_text (segments, scopebuddy_args_field.get_text ());
                    break;
                default:
                    break;
            }

            if (command_tile.toggle.get_active ()) {
                if (selected_wrapper_mode != WrapperMode.NONE)
                segments.add ("-- %command%");
                else
                segments.add ("%command%");
            }

            return segments;
        }

        void append_segments_from_text (Gee.LinkedList<string> segments, string launch_options) {
            foreach (var token in get_launch_option_tokens (launch_options)) {
                if (token == "")
                continue;

                segments.add (token);
            }
        }

        void append_none_segments (Gee.LinkedList<string> segments) {
            if (hdr_tile.toggle.get_active ())
            segments.add ("PROTON_ENABLE_HDR=1");
        }

        void apply_game_argument_bindings_from_tokens (string[] tokens, bool[] consumed, int command_index) {
            if (command_index < 0)
            return;

            foreach (var binding in game_argument_bindings) {
                var token_indexes = new Gee.LinkedList<int> ();
                var all_tokens_present = true;

                foreach (var token in binding.tokens) {
                    var token_index = get_unconsumed_token_index_after (tokens, token, consumed, command_index + 1);
                    if (token_index < 0) {
                        all_tokens_present = false;
                        break;
                    }

                    token_indexes.add (token_index);
                }

                if (!all_tokens_present)
                continue;

                binding.toggle.set_active (true);
                foreach (var token_index in token_indexes) {
                    consumed[token_index] = true;
                }
            }
        }

        bool has_active_binding (List<LaunchOptionBinding> bindings) {
            foreach (var binding in bindings) {
                if (binding.toggle.get_active ())
                return true;
            }

            return false;
        }

        void reset_binding_toggles (List<LaunchOptionBinding> bindings) {
            foreach (var binding in bindings) {
                binding.toggle.set_active (false);
            }
        }

        void amd_fsr4_upgrade_toggle_changed () {
            if (refreshing_controls)
            return;

            if (amd_fsr4_upgrade_tile.toggle.get_active () && amd_fsr4_rdna3_upgrade_tile.toggle.get_active ()) {
                refreshing_controls = true;
                amd_fsr4_rdna3_upgrade_tile.toggle.set_active (false);
                refreshing_controls = false;
            }

            standard_control_changed ();
        }

        void amd_fsr4_rdna3_upgrade_toggle_changed () {
            if (refreshing_controls)
            return;

            if (amd_fsr4_rdna3_upgrade_tile.toggle.get_active () && amd_fsr4_upgrade_tile.toggle.get_active ()) {
                refreshing_controls = true;
                amd_fsr4_upgrade_tile.toggle.set_active (false);
                refreshing_controls = false;
            }

            standard_control_changed ();
        }

        void normalize_amd_fsr_upgrade_dependencies () {
            if (!amd_fsr4_upgrade_tile.toggle.get_active () || !amd_fsr4_rdna3_upgrade_tile.toggle.get_active ())
            return;

            var was_refreshing = refreshing_controls;
            refreshing_controls = true;
            amd_fsr4_rdna3_upgrade_tile.toggle.set_active (false);
            refreshing_controls = was_refreshing;
        }

        void nvidia_nvapi_toggle_changed () {
            if (refreshing_controls)
            return;

            if (!nvapi_tile.toggle.get_active () && nvidia_ngx_updater_tile.toggle.get_active ()) {
                refreshing_controls = true;
                nvidia_ngx_updater_tile.toggle.set_active (false);
                refreshing_controls = false;
            }

            standard_control_changed ();
        }

        void nvidia_dlss_updater_toggle_changed () {
            if (refreshing_controls)
            return;

            if (nvidia_ngx_updater_tile.toggle.get_active () && !nvapi_tile.toggle.get_active ()) {
                refreshing_controls = true;
                nvapi_tile.toggle.set_active (true);
                refreshing_controls = false;
            }

            standard_control_changed ();
        }

        void normalize_nvidia_vendor_dependencies () {
            if (!nvidia_ngx_updater_tile.toggle.get_active () || nvapi_tile.toggle.get_active ())
            return;

            var was_refreshing = refreshing_controls;
            refreshing_controls = true;
            nvapi_tile.toggle.set_active (true);
            refreshing_controls = was_refreshing;
        }

        void refresh_preview () {
            preview_field.preview_label.set_markup (build_preview_markup ());
        }

        string build_preview_markup () {
            var segments = get_command_segments ();
            if (segments.size == 0)
            return "<tt><span foreground='#8b949e'>%s</span></tt>".printf (Markup.escape_text (_ ("No launch options configured yet.")));

            string[] preview_colors = {
                "#79c0ff",
                "#ff938a",
                "#7ee787",
                "#d2a8ff",
                "#e3b341",
                "#56d4dd"
            };
            var markup = new StringBuilder ();
            markup.append ("<tt>");

            for (var index = 0; index < segments.size; index++) {
                if (index > 0)
                markup.append (" ");

                var escaped_segment = Markup.escape_text (segments[index]);
                markup.append ("<span foreground='%s'>%s</span>".printf (preview_colors[index % preview_colors.length], escaped_segment));
            }

            markup.append ("</tt>");

            return markup.str;
        }

        void apply_bindings_from_tokens (List<LaunchOptionBinding> bindings, string[] tokens, bool[] consumed) {
            foreach (var binding in bindings) {
                var token_indexes = new Gee.LinkedList<int> ();
                var all_tokens_present = true;

                foreach (var token in binding.tokens) {
                    var token_index = get_unconsumed_token_index (tokens, token, consumed);
                    if (token_index < 0) {
                        all_tokens_present = false;
                        break;
                    }

                    token_indexes.add (token_index);
                }

                if (!all_tokens_present)
                continue;

                binding.toggle.set_active (true);
                foreach (var token_index in token_indexes) {
                    consumed[token_index] = true;
                }
            }
        }

        void parse_gamescope_tokens (string[] tokens, bool[] consumed) {
            var wrapper_index = get_first_present_index (tokens, { "gamescope" });
            if (wrapper_index < 0)
            return;

            consumed[wrapper_index] = true;

            var end_index = get_wrapper_end_index (tokens, wrapper_index, consumed);
            var extra_args = new StringBuilder ();

            for (var index = wrapper_index + 1; index < end_index; index++) {
                var token = tokens[index];

                if (consumed[index]) continue;

                if (token == "-f") {
                    gamescope_fullscreen_tile.toggle.set_active (true);
                    consumed[index] = true;
                    continue;
                }

                if (token == "--hdr-enabled") {
                    gamescope_hdr_tile.toggle.set_active (true);
                    consumed[index] = true;
                    continue;
                }

                if (token == "--adaptive-sync") {
                    gamescope_vrr_tile.toggle.set_active (true);
                    consumed[index] = true;
                    continue;
                }

                if (token == "-r" && index + 1 < end_index) {
                    int framerate;
                    if (int.try_parse (tokens[index + 1], out framerate)) {
                        gamescope_framerate_tile.toggle.set_active (true);
                        gamescope_framerate_tile.set_value (framerate);
                        consumed[index] = true;
                        consumed[index + 1] = true;
                        index++;
                        continue;
                    }
                }

                append_token (extra_args, token);
                consumed[index] = true;
            }

            gamescope_args_field.set_text (extra_args.str);
        }

        void parse_none_tokens (string[] tokens, bool[] consumed) {
            var hdr_index = get_unconsumed_token_index (tokens, "PROTON_ENABLE_HDR=1", consumed);
            if (hdr_index < 0)
            return;

            hdr_tile.toggle.set_active (true);
            consumed[hdr_index] = true;
        }

        void parse_scopebuddy_tokens (string[] tokens, bool[] consumed) {

            var wrapper_index = get_first_present_index (tokens, { "scopebuddy", "scb" });
            if (wrapper_index < 0)
            return;

            consumed[wrapper_index] = true;

            var end_index = get_wrapper_end_index (tokens, wrapper_index, consumed);
            var extra_args = new StringBuilder ();

            for (var index = wrapper_index + 1; index < end_index; index++) {
                if (consumed[index]) continue;

                if (tokens[index] == "-f") {
                    scopebuddy_fullscreen_tile.toggle.set_active (true);
                    consumed[index] = true;
                    continue;
                }

                if (tokens[index] == "-r" && index + 1 < end_index) {
                    int framerate;
                    if (int.try_parse (tokens[index + 1], out framerate)) {
                        scopebuddy_framerate_tile.toggle.set_active (true);
                        scopebuddy_framerate_tile.set_value (framerate);
                        consumed[index] = true;
                        consumed[index + 1] = true;
                        index++;
                        continue;
                    }
                }

                append_token (extra_args, tokens[index]);
                consumed[index] = true;
            }

            scopebuddy_args_field.set_text (extra_args.str);
        }

        WrapperMode detect_wrapper_mode (string[] tokens) {
            var gamescope_index = get_first_present_index (tokens, { "gamescope" });
            var scopebuddy_index = get_first_present_index (tokens, { "scopebuddy", "scb" });

            if (gamescope_index >= 0 && scopebuddy_index >= 0)
            return WrapperMode.NONE;

            if (gamescope_index >= 0)
            return WrapperMode.GAMESCOPE;

            if (scopebuddy_index >= 0)
            return WrapperMode.SCOPEBUDDY;

            return WrapperMode.NONE;
        }

        int get_wrapper_end_index (string[] tokens, int wrapper_index, bool[] consumed) {
            var command_index = get_token_index (tokens, "%command%");
            if (command_index > wrapper_index && command_index > 0 && tokens[command_index - 1] == "--") {
                consumed[command_index - 1] = true;
                return command_index - 1;
            }

            return tokens.length;
        }

        int get_first_present_index (string[] tokens, string[] candidates) {
            for (var index = 0; index < tokens.length; index++) {
                foreach (var candidate in candidates) {
                    if (tokens[index] == candidate)
                    return index;
                }
            }

            return -1;
        }

        int get_unconsumed_token_index (string[] tokens, string token, bool[] consumed) {
            for (var index = 0; index < tokens.length; index++) {
                if (!consumed[index] && tokens[index] == token)
                return index;
            }

            return -1;
        }

        int get_unconsumed_token_index_after (string[] tokens, string token, bool[] consumed, int start_index) {
            for (var index = start_index; index < tokens.length; index++) {
                if (!consumed[index] && tokens[index] == token)
                return index;
            }

            return -1;
        }

        int get_token_index (string[] tokens, string token) {
            for (var index = 0; index < tokens.length; index++) {
                if (tokens[index] == token)
                return index;
            }

            return -1;
        }

        string join_unconsumed_tokens (string[] tokens, bool[] consumed) {
            var output = new StringBuilder ();

            for (var index = 0; index < tokens.length; index++) {
                if (consumed[index] || tokens[index] == "")
                continue;

                append_token (output, tokens[index]);
            }

            return output.str;
        }

        void select_preferred_gpu_vendor_page () {
            if (amd_anti_lag_tile.toggle.get_active () || amd_prime_tile.toggle.get_active () || amd_hide_apu_tile.toggle.get_active () || amd_fsr4_upgrade_tile.toggle.get_active () || amd_fsr4_rdna3_upgrade_tile.toggle.get_active ()) {
                gpu_vendor_stack.set_visible_child_name ("amd");
                return;
            }

            if (nvapi_tile.toggle.get_active () || nvidia_ngx_updater_tile.toggle.get_active () || nvidia_hide_gpu_tile.toggle.get_active ()) {
                gpu_vendor_stack.set_visible_child_name ("nvidia");
                return;
            }

            if (intel_xess_upgrade_tile.toggle.get_active ()) {
                gpu_vendor_stack.set_visible_child_name ("intel");
                return;
            }

            gpu_vendor_stack.set_visible_child_name ("amd");
        }

        string[] get_launch_option_tokens (string launch_options) {
            return normalize_launch_options (launch_options).split (" ");
        }

        string normalize_launch_options (string launch_options) {
            var output = new StringBuilder ();

            foreach (var token in launch_options.strip ().split (" ")) {
                if (token == "")
                continue;

                append_token (output, token);
            }

            return output.str;
        }

        WrapperMode get_selected_wrapper_mode () {
            switch (wrapper_stack.get_visible_child_name ()) {
                case "gamescope":
                    return WrapperMode.GAMESCOPE;
                case "scopebuddy":
                    return WrapperMode.SCOPEBUDDY;
                default:
                    return WrapperMode.NONE;
            }
        }

        void set_selected_wrapper_mode (WrapperMode wrapper_mode) {
            switch (wrapper_mode) {
                case WrapperMode.GAMESCOPE:
                    wrapper_stack.set_visible_child_name ("gamescope");
                    break;
                case WrapperMode.SCOPEBUDDY:
                    wrapper_stack.set_visible_child_name ("scopebuddy");
                    break;
                default:
                    wrapper_stack.set_visible_child_name ("none");
                    break;
            }
        }

        void append_token (StringBuilder output, string token) {
            if (output.len > 0)
            output.append (" ");

            output.append (token);
        }
    }
}
