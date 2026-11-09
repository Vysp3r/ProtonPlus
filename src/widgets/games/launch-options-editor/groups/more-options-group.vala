namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class MoreOptionsGroup : BaseOptionsGroup {

        LaunchOptionTile vkbasalt_tile { get; private set; }
        LaunchOptionTile wined3d_tile { get; private set; }
        LaunchOptionTile ntsync_tile { get; private set; }
        LaunchOptionTile local_shader_cache_tile { get; private set; }
        LaunchOptionTile prefer_sdl_tile { get; private set; }
        LaunchOptionTile no_steaminput_tile { get; private set; }
        LaunchOptionTile wine_vk_use_sync2_tile { get; private set; }
        LaunchOptionTile wine_sync_use_futex_waitv_tile { get; private set; }
        LaunchOptionTile wine_writecopy_tile { get; private set; }

        public MoreOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, true, presentation_registry);

            this.title = _("More options");
            this.description = _("Extra graphics settings and launch behaviors.");

            vkbasalt_tile = create_tile ("vkbasalt", true);
            wined3d_tile = create_tile ("wined3d", true);
            ntsync_tile = create_tile ("ntsync-mode", true);
            local_shader_cache_tile = create_tile ("per-game-shader-cache", true);
            prefer_sdl_tile = create_tile ("prefer-sdl");
            no_steaminput_tile = create_tile ("bypass-steam-input");
            wine_vk_use_sync2_tile = create_tile ("vulkan-sync2");
            wine_sync_use_futex_waitv_tile = create_tile ("futex-waitv");
            wine_writecopy_tile = create_tile ("writecopy");

            this.add (vkbasalt_tile);
            this.add (wined3d_tile);
            this.add (ntsync_tile);
            this.add (local_shader_cache_tile);
            this.add (prefer_sdl_tile);
            this.add (no_steaminput_tile);
            this.add (wine_vk_use_sync2_tile);
            this.add (wine_sync_use_futex_waitv_tile);
            this.add (wine_writecopy_tile);
        }

        public override bool has_advanced_active () {
            return vkbasalt_tile.toggle.get_active ()
                   || wined3d_tile.toggle.get_active ()
                   || ntsync_tile.toggle.get_active ()
                   || local_shader_cache_tile.toggle.get_active ();
        }
    }
}
