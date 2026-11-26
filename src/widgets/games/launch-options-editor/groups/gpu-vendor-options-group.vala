namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    public class GpuVendorOptionsGroup : Object {
        public signal void changed ();

        GpuVendorAmdOptionsGroup amd_group;
        GpuVendorNvidiaOptionsGroup nvidia_group;
        GpuVendorIntelOptionsGroup intel_group;

        public GpuVendorOptionsGroup (LaunchOptionsList launch_option_handlers,
            LaunchOptionPresentationRegistry? presentation_registry = null) {
            amd_group = new GpuVendorAmdOptionsGroup (launch_option_handlers, presentation_registry);
            nvidia_group = new GpuVendorNvidiaOptionsGroup (launch_option_handlers, presentation_registry);
            intel_group = new GpuVendorIntelOptionsGroup (launch_option_handlers, presentation_registry);

            amd_group.changed.connect (() => changed ());
            nvidia_group.changed.connect (() => changed ());
            intel_group.changed.connect (() => changed ());
        }

        internal void reset_controls () {
            amd_group.reset_controls ();
            nvidia_group.reset_controls ();
            intel_group.reset_controls ();
        }

        internal void normalize_dependencies () {
            amd_group.normalize_amd_fsr_upgrade_dependencies ();
        }
    }
}
