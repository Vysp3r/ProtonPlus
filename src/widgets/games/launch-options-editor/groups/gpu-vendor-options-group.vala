namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GpuVendorOptionsGroup : Gtk.Box {
        public signal void changed ();

        Gtk.Stack stack { get; set; }
        Gtk.StackSwitcher switcher { get; set; }

        GpuVendorAmdOptionsGroup amd_group { get; set; }
        GpuVendorNvidiaOptionsGroup nvidia_group { get; set; }
        GpuVendorIntelOptionsGroup intel_group { get; set; }

        public GpuVendorOptionsGroup (LaunchOptionsList launch_option_handlers) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);

            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.set_margin_bottom (4);

            var title_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            title_vbox.set_hexpand (true);

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

            stack.set_visible_child_name ("amd");

            switcher = new Gtk.StackSwitcher ();
            switcher.set_stack (stack);
            switcher.set_halign (Gtk.Align.START);

            header_box.append (title_vbox);
            header_box.append (switcher);

            this.append (header_box);
            this.append (stack);
        }

        internal void reset_controls () {
            amd_group.reset_controls ();
            nvidia_group.reset_controls ();
            intel_group.reset_controls ();
            select_preferred_page ();
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

        internal void select_preferred_page () {
            if (amd_group.is_any_tile_active ()) {
                stack.set_visible_child_name ("amd");
                return;
            }
            if (nvidia_group.is_any_tile_active ()) {
                stack.set_visible_child_name ("nvidia");
                return;
            }
            if (intel_group.is_any_tile_active ()) {
                stack.set_visible_child_name ("intel");
                return;
            }
            stack.set_visible_child_name ("amd");
        }
    }
}
