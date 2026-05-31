namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GpuVendorIntelOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile intel_xess_upgrade_tile { get; set; }

        public GpuVendorIntelOptionsGroup (owned SimpleCallback standard_control_changed, Gee.List<ILaunchOption> launch_option_handlers) {
            base((owned) standard_control_changed, launch_option_handlers, true);

            intel_xess_upgrade_tile = create_tile (_ ("XeSS Upgrade"), _ ("Upgrades XeSS in supported games."), { "PROTON_XESS_UPGRADE=1" }, false);

            this.add (intel_xess_upgrade_tile);

        }

        internal void reset_controls () {
            intel_xess_upgrade_tile.toggle.set_active (false);
        }

        internal bool is_any_tile_active () {
            return intel_xess_upgrade_tile.toggle.get_active ();
        }
    }
}
