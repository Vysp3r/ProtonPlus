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
        Groups.GameArgumentsGroup game_arguments_group { get; set; }
        Groups.AdvancedOptionsGroup advanced_options_group { get; set; }

        LaunchOptionPreviewField preview_field { get; set; }
        Groups.DxvkOptionsGroup dxvk_options_group { get; set; }
        Groups.Vkd3dOptionsGroup vkd3d_options_group;
        Groups.GpuVendorOptionsGroup gpu_vendor_group;
        Groups.WrapperGroup wrapper_group;
        LaunchOptionsList launch_option_handlers;
        bool advanced_visible;
        bool refreshing_controls;

        construct {
            launch_option_handlers = new LaunchOptionsList ();
            advanced_visible = false;
            refreshing_controls = true;

            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (15);

            // Launch command preview

            preview_field = new LaunchOptionPreviewField (_("Launch command preview"));
            append (preview_field);

            // Common options
            var common_group = new Groups.CommonOptionsGroup (standard_control_changed, launch_option_handlers);
            append (common_group);

            // Launch tools

            wrapper_group = new Groups.WrapperGroup (standard_control_changed, launch_option_handlers);
            append (wrapper_group);

            // GPU vendor options
            gpu_vendor_group = new Groups.GpuVendorOptionsGroup (standard_control_changed, launch_option_handlers);
            append (gpu_vendor_group);

            // DXVK options
            dxvk_options_group = new Groups.DxvkOptionsGroup (standard_control_changed, launch_option_handlers);
            append (dxvk_options_group);

            // VKD3D options
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
            game_arguments_group = new Groups.GameArgumentsGroup (standard_control_changed, launch_option_handlers);
            append (game_arguments_group);

            // Advanced options

            advanced_options_group = new Groups.AdvancedOptionsGroup (standard_control_changed, launch_option_handlers);
            append (advanced_options_group);

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

            foreach (var handler in this.launch_option_handlers) {
                if (handler.is_active ()) {
                    return true;
                }
            }

            return false;
        }

        public string get_text () {
            return launch_option_handlers.to_launch_line ();
        }

        public void set_text (string launch_options) {
            var tokens = get_launch_option_tokens (launch_options);
            var consumed = new bool[tokens.length];
            refreshing_controls = true;

            reset_controls ();

            foreach (var editor in launch_option_handlers) {
                editor.parse_tokens (tokens, consumed);
            }

            gpu_vendor_group.normalize_dependencies ();

            var command_index = get_token_index (tokens, "%command%");
            if (command_index >= 0)
                consumed[command_index] = true;

            gpu_vendor_group.select_preferred_page ();

            advanced_visible = should_show_advanced_controls ();
            refresh_advanced_visibility ();

            refreshing_controls = false;
            refresh_preview ();
        }

        void reset_controls () {
            gpu_vendor_group.reset_controls ();

            foreach (var editor in launch_option_handlers) {
                editor.clear ();
            }
        }

        void standard_control_changed () {
            if (refreshing_controls)
                return;

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
            advanced_options_group.set_visible (is_advanced);
        }

        bool should_show_advanced_controls () {
            foreach (var handler in this.launch_option_handlers) {
                if (handler.is_advanced && handler.is_active ()) {
                    return true;
                }
            }

            return false;
        }

        void refresh_preview () {
            preview_field.preview_label.set_markup (launch_option_handlers.build_preview_markup ());
        }

        int get_token_index (string[] tokens, string token) {
            for (var index = 0; index < tokens.length; index++) {
                if (tokens[index] == token)
                    return index;
            }

            return -1;
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

        void append_token (StringBuilder output, string token) {
            if (output.len > 0)
                output.append (" ");

            output.append (token);
        }
    }
}