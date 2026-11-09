namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GpuVendorNvidiaOptionsGroup : BaseOptionsGroup {

        LaunchOptionTile nvapi_tile { get; set; }
        LaunchOptionTile nvidia_ngx_updater_tile { get; set; }
        LaunchOptionTile nvidia_hide_gpu_tile { get; set; }
        LaunchOptionTile dlss_indicator_tile { get; set; }
        LaunchOptionTile nvidia_libs_tile { get; set; }

        public GpuVendorNvidiaOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, true, presentation_registry, false);
            nvapi_tile = create_tile ("nvidia-nvapi");
            // gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_ENABLE_NVAPI=1" }, nvapi_tile.toggle));
            nvidia_ngx_updater_tile = create_tile ("nvidia-dlss-updater");
            // gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_ENABLE_NGX_UPDATER=1" }, nvidia_ngx_updater_tile.toggle));
            nvidia_hide_gpu_tile = create_tile ("nvidia-report-amd");
            dlss_indicator_tile = create_tile ("nvidia-dlss-indicator");
            nvidia_libs_tile = create_tile ("nvidia-libraries");

            this.add (nvapi_tile);
            this.add (nvidia_ngx_updater_tile);
            this.add (nvidia_hide_gpu_tile);
            this.add (dlss_indicator_tile);
            this.add (nvidia_libs_tile);
        }

        internal void reset_controls () {
            nvapi_tile.toggle.set_active (false);
            nvidia_ngx_updater_tile.toggle.set_active (false);
            nvidia_hide_gpu_tile.toggle.set_active (false);
            dlss_indicator_tile.toggle.set_active (false);
            nvidia_libs_tile.toggle.set_active (false);
        }

    }
}
