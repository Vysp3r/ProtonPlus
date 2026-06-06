namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    enum WrapperMode {
        NONE,
        GAMESCOPE,
        SCOPEBUDDY
    }

    public class Box : Gtk.Box {
        public signal void content_changed ();
        public signal void advanced_state_detected (bool is_advanced);

        Groups.ProtonOptionsGroup proton_options_group { get; set; }
        Groups.AudioOptionsGroup audio_group { get; set; }
        Groups.MoreOptionsGroup more_options_group { get; set; }
        Groups.GameArgumentsGroup game_arguments_group { get; set; }
        Groups.AdvancedOptionsGroup advanced_options_group { get; set; }
        Groups.CommonOptionsGroup common_group { get; set; }
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
            common_group = new Groups.CommonOptionsGroup (standard_control_changed, launch_option_handlers);
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

            preview_field.set_visible (advanced_visible);
            more_options_group.set_visible (advanced_visible);
            proton_options_group.set_visible (advanced_visible);
            gpu_vendor_group.set_visible (advanced_visible);
            game_arguments_group.set_visible (advanced_visible);
            advanced_options_group.set_visible (advanced_visible);

            standard_control_changed ();
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
            refreshing_controls = true;

            gpu_vendor_group.reset_controls ();

            var has_advanced = launch_option_handlers.load_from_string (launch_options);

            gpu_vendor_group.normalize_dependencies ();
            gpu_vendor_group.select_preferred_page ();

            advanced_visible = has_advanced;
            this.advanced_state_detected (advanced_visible);
            refresh_advanced_visibility ();

            refreshing_controls = false;
            standard_control_changed ();
        }

        void standard_control_changed () {
            refresh_preview ();
            content_changed ();
        }

        void refresh_advanced_visibility_state () {
            preview_field.set_visible (advanced_visible);
            more_options_group.set_visible (advanced_visible);
            proton_options_group.set_visible (advanced_visible);
            gpu_vendor_group.set_visible (advanced_visible);
            game_arguments_group.set_visible (advanced_visible);
            advanced_options_group.set_visible (advanced_visible);
        }

        void refresh_advanced_visibility () {
            refresh_advanced_visibility_state ();
        }

        void refresh_preview () {
            preview_field.preview_label.set_markup (launch_option_handlers.build_preview_markup ());
        }
    }
}