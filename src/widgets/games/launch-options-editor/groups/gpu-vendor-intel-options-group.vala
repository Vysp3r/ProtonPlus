namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GpuVendorIntelOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile intel_xess_upgrade_tile { get; set; }

        public GpuVendorIntelOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, true, presentation_registry, false);

            intel_xess_upgrade_tile = create_tile ("intel-xess");

            this.add (intel_xess_upgrade_tile);
        }

        internal void reset_controls () {
            intel_xess_upgrade_tile.toggle.set_active (false);
        }

    }
}
