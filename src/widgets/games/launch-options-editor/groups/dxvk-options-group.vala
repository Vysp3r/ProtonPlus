namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class DxvkOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile dxvk_async_tile { get; private set; }
        LaunchOptionTile dxvk_log_level_none_tile { get; private set; }
        LaunchOptionSpinTile dxvk_frame_rate_tile { get; private set; }
        LaunchOptionTile cachyos_dxvk_low_latency_tile { get; private set; }
        LaunchOptionTile cachyos_vulkan_low_latency_tile { get; private set; }
        LaunchOptionTile cachyos_vulkan_reflex_tile { get; private set; }
        LaunchOptionTile cachyos_vulkan_reflex_layer_tile { get; private set; }

        public DxvkOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, true, presentation_registry);

            this.title = _("DXVK options");
            this.description = _("Extra graphics settings and launch behaviors.");

            dxvk_async_tile = create_tile (
                                           _("DXVK Async"),
                                           _("Enables DXVK's asynchronous pipeline compilation which can reduce stuttering."),
                                           { "DXVK_ASYNC=1" }, false, LaunchLineType.ENVIRONMENT, "dxvk-async");

            dxvk_log_level_none_tile = create_tile (
                                                    _("Disable DXVK logging"),
                                                    _("Sets DXVK's log level to none which can improve performance in some games."),
                                                    { "DXVK_LOG_LEVEL=none" }, false, LaunchLineType.ENVIRONMENT, "dxvk-log-level");

            dxvk_frame_rate_tile = create_spin_tile (
                                                     _("DXVK Frame Limit"),
                                                     _("Caps the frame rate using DXVK's built-in frame limiter."),
                                                     _("FPS"),
                                                     0,
                                                     360,
                                                     60,
                                                     "DXVK_FRAME_RATE=",
                                                     false,
                                                     LaunchLineType.ENVIRONMENT,
                                                     "dxvk-frame-limit"
            );

            cachyos_dxvk_low_latency_tile = create_tile (
                _("Proton-CachyOS DX11 low latency"),
                _("Enables the custom DXVK low-latency path for Direct3D 9–11."),
                { "PROTON_DXVK_LOWLATENCY=1" }, false, LaunchLineType.ENVIRONMENT,
                "cachyos-dxvk-low-latency"
            );
            cachyos_vulkan_low_latency_tile = create_tile (
                _("Proton-CachyOS Vulkan Anti-Lag 2 layer"),
                _("Exposes VK_AMD_anti_lag to Vulkan games that already support Anti-Lag 2."),
                { "LOW_LATENCY_LAYER=1" }, false, LaunchLineType.ENVIRONMENT,
                "cachyos-vulkan-low-latency"
            );
            cachyos_vulkan_reflex_tile = create_tile (
                _("Expose Vulkan Reflex instead of Anti-Lag 2"),
                _("Switches the low-latency Vulkan layer to VK_NV_low_latency2 for games with Reflex support."),
                { "LOW_LATENCY_LAYER_REFLEX=1" }, false, LaunchLineType.ENVIRONMENT,
                "cachyos-vulkan-reflex"
            );
            cachyos_vulkan_reflex_layer_tile = create_tile (
                _("Proton-CachyOS NVIDIA Reflex Vulkan layer"),
                _("Enables the NVIDIA Vulkan Reflex layer for games that support VK_NV_low_latency2."),
                { "DXVK_NVAPI_VKREFLEX=1" }, false, LaunchLineType.ENVIRONMENT,
                "cachyos-vulkan-reflex-layer"
            );
            this.add (dxvk_log_level_none_tile);
            this.add (dxvk_async_tile);
            this.add (dxvk_frame_rate_tile);
            this.add (cachyos_dxvk_low_latency_tile);
            this.add (cachyos_vulkan_low_latency_tile);
            this.add (cachyos_vulkan_reflex_tile);
            this.add (cachyos_vulkan_reflex_layer_tile);
        }
    }
}
