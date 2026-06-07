namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class Vkd3dOptionsGroup : BaseOptionsGroup {
        public LaunchOptionVKD3DConfig vkd3d_config_editor { get; private set; }
        public LaunchOptionVKD3DLogLevel vkd3d_log_level_editor { get; private set; }
        LaunchOptionTile vkd3d_gpuva_tile { get; private set; }
        LaunchOptionTile vkd3d_shader_cache_tile { get; private set; }

        public Vkd3dOptionsGroup (SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            base (standard_control_changed, launch_option_handlers);

            this.title = _("VKD3D options");
            this.description = _("Extra graphics settings and launch behaviors.");

            vkd3d_config_editor = new LaunchOptionVKD3DConfig ();
            vkd3d_config_editor.changed.connect ((row) => {
                standard_control_changed ();
            });
            vkd3d_config_editor.set_tooltip_text (_("Configure Direct3D 12 to Vulkan translation behavior"));

            vkd3d_log_level_editor = new LaunchOptionVKD3DLogLevel ();
            vkd3d_log_level_editor.changed.connect ((row) => {
                standard_control_changed ();
            });
            vkd3d_log_level_editor.set_tooltip_text (_("VKD3D Logging Level"));

            vkd3d_gpuva_tile = create_tile (
                                            _("Enable VKD3D GPUVA"),
                                            _("Enables GPU Virtual Addressing. Aligns Vulkan memory management with native DX12 behavior to improve texture streaming and stability in open-world games."),
                                            { "VKD3D_GPUVA=1" });

            vkd3d_shader_cache_tile = create_tile (
                                                   _("Enable VKD3D Shader Cache"),
                                                   _("Enables VKD3D's internal shader caching mechanism to minimize in-game stutter."),
                                                   { "VKD3D_SHADER_CACHE=1" });

            this.add (vkd3d_shader_cache_tile);
            this.add (vkd3d_gpuva_tile);
            this.add (vkd3d_config_editor);
            this.add (vkd3d_log_level_editor);

            launch_option_handlers.add (vkd3d_config_editor);
            launch_option_handlers.add (vkd3d_log_level_editor);
        }
    }
}