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
            nvapi_tile = create_tile (_("NVAPI"), _("Lets games access NVIDIA-specific features like DLSS."), { "PROTON_ENABLE_NVAPI=1" }, false, LaunchLineType.ENVIRONMENT, "nvidia-nvapi");
            // gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_ENABLE_NVAPI=1" }, nvapi_tile.toggle));
            nvidia_ngx_updater_tile = create_tile (
                _("DLSS component updates"),
                _("Auto upgrades DLSS components for supported games."),
                { "PROTON_ENABLE_NGX_UPDATER=1" }, false, LaunchLineType.ENVIRONMENT, "nvidia-dlss-updater"
            );
            // gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_ENABLE_NGX_UPDATER=1" }, nvidia_ngx_updater_tile.toggle));
            nvidia_hide_gpu_tile = create_tile (
                _("Report GPU as AMD"),
                _("Makes Proton report an NVIDIA GPU as AMD for games that expect Windows-only NVIDIA driver behavior."),
                { "PROTON_HIDE_NVIDIA_GPU=1" }, false, LaunchLineType.ENVIRONMENT, "nvidia-report-amd"
            );
            dlss_indicator_tile = create_tile (_("DLSS indicator"), _("Shows a DLSS status indicator in-game."), { "PROTON_DLSS_INDICATOR=1" }, false, LaunchLineType.ENVIRONMENT, "nvidia-dlss-indicator");
            nvidia_libs_tile = create_tile (
                _("NVIDIA libraries"),
                _("Enables NVIDIA-specific libraries (PhysX, CUDA). This is not needed for DLSS or ray tracing."),
                { "PROTON_NVIDIA_LIBS=1" }, false, LaunchLineType.ENVIRONMENT, "nvidia-libraries"
            );

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
