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

        public MoreOptionsGroup (owned SimpleCallback standard_control_changed, List<ILaunchOption> launch_option_handlers) {
            base(standard_control_changed, launch_option_handlers, true);

            this.title = _ ("More options");
            this.description = _ ("Extra graphics settings and launch behaviors.");

            vkbasalt_tile = create_tile (_ ("VKBasalt"), _ ("Adds visual effects like sharpening and color adjustments."), { "ENABLE_VKBASALT=1" }, true);
            wined3d_tile = create_tile (_ ("WineD3D"), _ ("Uses OpenGL instead of Vulkan. Only enable if you're having DXVK issues."), { "PROTON_USE_WINED3D=1" }, true);
            ntsync_tile = create_tile (_ ("Use FSync"), _ ("Uses FSync instead of NTSync. Can fix issues in certain games that do not pair well with NTSync."), { "PROTON_USE_NTSYNC=0" }, true);
            local_shader_cache_tile = create_tile (_ ("Local shader cache"), _ ("Enables per-game shader cache. This isolates the shader cache of each game but does not compile them ahead-of-time."), { "PROTON_LOCAL_SHADER_CACHE=1" }, true);
            prefer_sdl_tile = create_tile (_ ("Prefer SDL controller"), _ ("Workaround for controller detection issues."), { "PROTON_PREFER_SDL=1" });
            no_steaminput_tile = create_tile (_ ("Disable Steam Input"), _ ("Disables Steam Input support. Fixes Wayland controller/gamepad issues."), { "PROTON_NO_STEAMINPUT=1" });
            wine_vk_use_sync2_tile = create_tile (_ ("WINE_VK_USE_SYNC2"), _ ("Enables WINE_VK_USE_SYNC2 which can improve performance and reduce stuttering in some games when using WineD3D."), { "WINE_VK_USE_SYNC2=1" });
            wine_sync_use_futex_waitv_tile = create_tile (_ ("WINE_SYNC_USE_FUTEX_WAITV"), _ ("Enables WINE_SYNC_USE_FUTEX_WAITV which can improve performance and reduce stuttering in some games when using WineD3D."), { "WINE_SYNC_USE_FUTEX_WAITV=1" });
            wine_writecopy_tile = create_tile (_ ("Simulate Write-Copy Memory"), _ ("Forces Wine to simulate page-write protection, fixing initialization errors in certain older titles."), { "WINE_SIMULATE_WRITECOPY=1" });

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
