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

            dxvk_async_tile = create_tile ("dxvk-async");

            dxvk_log_level_none_tile = create_tile ("dxvk-log-level");

            dxvk_frame_rate_tile = create_spin_tile (
                                                     _("DXVK frame limit"),
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

            cachyos_dxvk_low_latency_tile = create_tile ("cachyos-dxvk-low-latency");
            cachyos_vulkan_low_latency_tile = create_tile ("cachyos-vulkan-low-latency");
            cachyos_vulkan_reflex_tile = create_tile ("cachyos-vulkan-reflex");
            cachyos_vulkan_reflex_layer_tile = create_tile ("cachyos-vulkan-reflex-layer");
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
