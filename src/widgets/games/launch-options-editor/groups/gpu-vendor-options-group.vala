namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GpuVendorOptionsGroup : Gtk.Box {
        public signal void changed ();

        Gtk.Stack stack { get; set; }

        GpuVendorAmdOptionsGroup amd_group { get; set; }
        GpuVendorNvidiaOptionsGroup nvidia_group { get; set; }
        GpuVendorIntelOptionsGroup intel_group { get; set; }
        bool advanced_visible;
        bool gpu_vendor_detected;

        public GpuVendorOptionsGroup (LaunchOptionsList launch_option_handlers) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            advanced_visible = false;
            gpu_vendor_detected = false;

            var title_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            title_vbox.set_hexpand (true);
            title_vbox.set_margin_bottom (4);

            var title_label = new Gtk.Label (_("GPU vendor options"));
            title_label.add_css_class ("title-4");
            title_label.set_halign (Gtk.Align.START);

            var desc_label = new Gtk.Label (_("Use GPU-specific compatibility toggles for AMD, NVIDIA and Intel hardware."));
            desc_label.add_css_class ("caption");
            desc_label.add_css_class ("dim-label");
            desc_label.set_halign (Gtk.Align.START);
            desc_label.set_wrap (true);

            title_vbox.append (title_label);
            title_vbox.append (desc_label);

            stack = new Gtk.Stack ();
            stack.set_hhomogeneous (false);
            stack.set_vhomogeneous (false);
            stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);

            amd_group = new GpuVendorAmdOptionsGroup (launch_option_handlers);
            nvidia_group = new GpuVendorNvidiaOptionsGroup (launch_option_handlers);
            intel_group = new GpuVendorIntelOptionsGroup (launch_option_handlers);

            amd_group.changed.connect (() => { this.changed (); });
            nvidia_group.changed.connect (() => { this.changed (); });
            intel_group.changed.connect (() => { this.changed (); });

            var amd_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0); amd_box.append (amd_group);
            var nvidia_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0); nvidia_box.append (nvidia_group);
            var intel_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0); intel_box.append (intel_group);

            stack.add_titled (amd_box, "amd", _("AMD"));
            stack.add_titled (nvidia_box, "nvidia", _("NVIDIA"));
            stack.add_titled (intel_box, "intel", _("Intel"));

            this.append (title_vbox);
            this.append (stack);

            Utils.System.detect_gpu_vendor.begin ((obj, result) => {
                select_detected_vendor (Utils.System.detect_gpu_vendor.end (result));
            });
        }

        void select_detected_vendor (Utils.GpuVendor vendor) {
            switch (vendor) {
                case Utils.GpuVendor.AMD:
                    stack.set_visible_child_name ("amd");
                    break;
                case Utils.GpuVendor.NVIDIA:
                    stack.set_visible_child_name ("nvidia");
                    break;
                case Utils.GpuVendor.INTEL:
                    stack.set_visible_child_name ("intel");
                    break;
                default:
                    break;
            }

            gpu_vendor_detected = vendor != Utils.GpuVendor.UNKNOWN;
            refresh_visibility ();
        }

        internal void set_advanced_visible (bool visible) {
            advanced_visible = visible;
            refresh_visibility ();
        }

        void refresh_visibility () {
            set_visible (advanced_visible && gpu_vendor_detected);
        }

        internal void reset_controls () {
            amd_group.reset_controls ();
            nvidia_group.reset_controls ();
            intel_group.reset_controls ();
        }

        internal void normalize_dependencies () {
            amd_group.normalize_amd_fsr_upgrade_dependencies ();
            nvidia_group.normalize_nvidia_vendor_dependencies ();
        }

        internal bool has_active_options () {
            return amd_group.has_active_options ()
                   || nvidia_group.has_active_options ()
                   || intel_group.has_active_options ();
        }

    }
}
