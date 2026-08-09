namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class Vkd3dOptionsGroup : BaseOptionsGroup {
        public LaunchOptionVKD3DConfig vkd3d_config_editor { get; private set; }
        public LaunchOptionVKD3DLogLevel vkd3d_log_level_editor { get; private set; }
        LaunchOptionTile vkd3d_gpuva_tile { get; private set; }
        LaunchOptionTile vkd3d_shader_cache_tile { get; private set; }
        LaunchOptionTile cachyos_vkd3d_low_latency_tile { get; private set; }

        public Vkd3dOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, true, presentation_registry);

            this.title = _("VKD3D options");
            this.description = _("Extra graphics settings and launch behaviors.");

            vkd3d_config_editor = new LaunchOptionVKD3DConfig ();
            vkd3d_config_editor.changed.connect ((row) => {
                this.changed ();
            });
            vkd3d_config_editor.set_tooltip_text (_("Configure Direct3D 12 to Vulkan translation behavior"));

            vkd3d_log_level_editor = new LaunchOptionVKD3DLogLevel ();
            vkd3d_log_level_editor.changed.connect ((row) => {
                this.changed ();
            });
            vkd3d_log_level_editor.set_tooltip_text (_("VKD3D Logging Level"));

            vkd3d_gpuva_tile = create_tile (
                _("Enable VKD3D GPUVA"),
                _("Enables GPU Virtual Addressing. Aligns Vulkan memory management with native DX12 behavior to improve texture streaming and stability in open-world games."), // vala-lint=line-length
                { "VKD3D_GPUVA=1" }, false, LaunchLineType.ENVIRONMENT, "vkd3d-gpuva"
            );

            vkd3d_shader_cache_tile = create_tile (
                _("Enable VKD3D Shader Cache"),
                _("Enables VKD3D's internal shader caching mechanism to minimize in-game stutter."),
                { "VKD3D_SHADER_CACHE=1" }, false, LaunchLineType.ENVIRONMENT, "vkd3d-shader-cache"
            );
            cachyos_vkd3d_low_latency_tile = create_tile (
                _("Proton-CachyOS DX12 low latency"),
                _("Uses Reflex markers or waitable swapchains. Intel GPUs and frame generation are unsupported."),
                { "PROTON_VKD3D_LOWLATENCY=1" }, false, LaunchLineType.ENVIRONMENT,
                "cachyos-vkd3d-low-latency"
            );

            this.add (vkd3d_shader_cache_tile);
            this.add (vkd3d_gpuva_tile);
            this.add (cachyos_vkd3d_low_latency_tile);
            this.add (vkd3d_config_editor);
            this.add (vkd3d_log_level_editor);

            launch_option_handlers.add (vkd3d_config_editor);
            launch_option_handlers.add (vkd3d_log_level_editor);
            register_option ("vkd3d-config", vkd3d_config_editor, vkd3d_config_editor);
            register_option ("vkd3d-log-level", vkd3d_log_level_editor, vkd3d_log_level_editor);
        }
    }
}
