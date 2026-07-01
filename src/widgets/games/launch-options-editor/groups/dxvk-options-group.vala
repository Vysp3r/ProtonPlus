namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class DxvkOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile dxvk_async_tile { get; private set; }
        LaunchOptionTile dxvk_log_level_none_tile { get; private set; }
        LaunchOptionSpinTile dxvk_frame_rate_tile { get; private set; }

        public DxvkOptionsGroup (LaunchOptionsList launch_option_handlers) {
            base (launch_option_handlers, true);

            this.title = _("DXVK options");
            this.description = _("Extra graphics settings and launch behaviors.");

            dxvk_async_tile = create_tile (
                                           _("DXVK Async"),
                                           _("Enables DXVK's asynchronous pipeline compilation which can reduce stuttering."),
                                           { "DXVK_ASYNC=1" });

            dxvk_log_level_none_tile = create_tile (
                                                    _("Disable DXVK logging"),
                                                    _("Sets DXVK's log level to none which can improve performance in some games."),
                                                    { "DXVK_LOG_LEVEL=none" });

            dxvk_frame_rate_tile = create_spin_tile (
                                                     _("DXVK Frame Limit"),
                                                     _("Caps the frame rate using DXVK's built-in frame limiter."),
                                                     _("FPS"),
                                                     0,
                                                     360,
                                                     60,
                                                     "DXVK_FRAME_RATE="
            );
            this.add (dxvk_log_level_none_tile);
            this.add (dxvk_async_tile);
            this.add (dxvk_frame_rate_tile);
        }
    }
}
