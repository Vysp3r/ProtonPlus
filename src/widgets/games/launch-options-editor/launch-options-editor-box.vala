namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    enum WrapperMode {
        NONE,
        GAMESCOPE,
        SCOPEBUDDY
    }

    public class Box : Gtk.Box {
        public signal void content_changed ();

        Groups.ProtonOptionsGroup proton_options_group { get; set; }
        Groups.AudioOptionsGroup audio_group { get; set; }
        Groups.MoreOptionsGroup more_options_group { get; set; }
        Adw.PreferencesGroup game_arguments_group { get; set; }
        Adw.PreferencesGroup advanced_options_group { get; set; }
        LaunchOptionTile hdr_tile { get; set; }
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
        Groups.DxvkOptionsGroup dxvk_options_group { get; set; }
        Groups.Vkd3dOptionsGroup vkd3d_options_group;
        Groups.GpuVendorOptionsGroup gpu_vendor_group;
        List<LaunchOptionBinding> game_argument_bindings;
        List<LaunchOptionBinding> scopebuddy_bindings;
        LaunchOptionsList launch_option_handlers;
        bool advanced_visible;
        bool refreshing_controls;
        bool can_auto_enable_command;

        construct {
            game_argument_bindings = new List<LaunchOptionBinding> ();
            scopebuddy_bindings = new List<LaunchOptionBinding> ();
            launch_option_handlers = new LaunchOptionsList ();
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
            gpu_vendor_group = new Groups.GpuVendorOptionsGroup (standard_control_changed, launch_option_handlers);
            append (gpu_vendor_group);

            //  DXVK options
            dxvk_options_group = new Groups.DxvkOptionsGroup (standard_control_changed, launch_option_handlers);
            append (dxvk_options_group);

            //  VKD3D options
            vkd3d_options_group = new Groups.Vkd3dOptionsGroup (standard_control_changed, launch_option_handlers);
            append (vkd3d_options_group);

            // More options

            more_options_group = new Groups.MoreOptionsGroup (standard_control_changed, launch_option_handlers);
            append (more_options_group);

            // Proton options

            proton_options_group = new Groups.ProtonOptionsGroup (standard_control_changed, launch_option_handlers);
            append (proton_options_group);

            // Audio options

            audio_group = new Groups.AudioOptionsGroup (standard_control_changed, launch_option_handlers);
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

            foreach (var binding in game_argument_bindings) {
                launch_option_handlers.add (binding);
            }
            foreach (var binding in scopebuddy_bindings) {
                launch_option_handlers.add (binding);
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

            foreach (var handler in this.launch_option_handlers) {
                if (handler.is_active()) {
                    return true;
                }
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

                gpu_vendor_group.normalize_dependencies ();

                var command_index = get_token_index (tokens, "%command%");
                apply_game_argument_bindings_from_tokens (tokens, consumed, command_index);
                command_tile.toggle.set_active (command_index >= 0);
                if (command_index >= 0)
                consumed[command_index] = true;

                set_selected_wrapper_mode (selected_wrapper_mode);
                var additional_args = join_unconsumed_tokens (tokens, consumed);
                additional_args_field.set_text (additional_args);
                additional_args_tile.toggle.set_active (additional_args != "");
                gpu_vendor_group.select_preferred_page ();

                advanced_visible = should_show_advanced_controls ();
                refresh_advanced_visibility ();

                can_auto_enable_command = command_index < 0;
                refreshing_controls = false;
                maybe_auto_enable_command ();
                refresh_preview ();
        }

        LaunchOptionTile create_game_argument_tile (string title, string subtitle, string[] tokens) {
            var tile = new LaunchOptionTile (title, subtitle);
            tile.toggle.notify["active"].connect (standard_control_changed);

            game_argument_bindings.append (new LaunchOptionBinding (tokens, tile.toggle, false, LaunchLineType.ARGUMENT));

            return tile;
        }

        Gtk.Widget create_none_page () {
            var group = new Adw.PreferencesGroup ();
            group.add (hdr_tile);
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

            gamescope_framerate_tile = new LaunchOptionSpinTile (_ ("Frame limit"), _ ("Caps the frame rate inside Gamescope."), _ ("FPS"), 30, 360, 60, "-r ");
            gamescope_framerate_tile.toggle.notify["active"].connect (standard_control_changed);
            gamescope_framerate_tile.value_applied.connect (standard_control_changed);

            gamescope_resolution_field = new LaunchOptionResolutionField (_ ("Resolution"), _ ("Sets the Gamescope output resolution."), false, false);
            gamescope_resolution_field.toggle.notify["active"].connect (standard_control_changed);
            gamescope_resolution_field.dropdown.notify["selected"].connect (standard_control_changed);
            gamescope_resolution_field.value_applied.connect (standard_control_changed);

            launch_option_handlers.add (gamescope_resolution_field);

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

            scopebuddy_framerate_tile = new LaunchOptionSpinTile (_ ("Frame limit"), _ ("Caps the frame rate inside ScopeBuddy."), _ ("FPS"), 30, 360, 60, "-r ");
            scopebuddy_framerate_tile.toggle.notify["active"].connect (standard_control_changed);
            scopebuddy_framerate_tile.value_applied.connect (standard_control_changed);

            scopebuddy_bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_HDR=1" }, scopebuddy_auto_hdr_tile.toggle));
            scopebuddy_bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_VRR=1" }, scopebuddy_auto_vrr_tile.toggle));

            scopebuddy_resolution_field = new LaunchOptionResolutionField (_ ("Resolution"), _ ("Sets the ScopeBuddy output resolution."), true, true);
            scopebuddy_resolution_field.toggle.notify["active"].connect (standard_control_changed);
            scopebuddy_resolution_field.dropdown.notify["selected"].connect (standard_control_changed);
            scopebuddy_resolution_field.value_applied.connect (standard_control_changed);
            launch_option_handlers.add (scopebuddy_resolution_field);

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
            gpu_vendor_group.reset_controls ();

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

        bool should_show_advanced_controls () {
            foreach (var handler in this.launch_option_handlers) {
                if (handler.is_advanced && handler.is_active ()) {
                    return true;
                }
            }

            return has_active_binding (game_argument_bindings)
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
            // TODO: activate after all will in launch_option_handlers
            //var segments = launch_option_handlers.get_segments ();

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
