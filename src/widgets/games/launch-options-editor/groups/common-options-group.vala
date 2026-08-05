namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class CommonOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile mangohud_tile { get; private set; }
        LaunchOptionTile steam_deck_tile { get; private set; }
        LaunchOptionTile wayland_tile { get; private set; }
        LaunchOptionTile gamemode_tile { get; private set; }
        LaunchOptionTile game_performance_tile { get; private set; }
        LaunchOptionTile mangohud_vulkan_tile { get; private set; }
        LaunchOptionTile obs_vkcapture_tile { get; private set; }

        public CommonOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, false, presentation_registry);

            this.title = _("Common options");
            this.description = _("Quick toggles for the launch options people reach for most often.");

            mangohud_tile = create_tile (
                                         _("MangoHud performance overlay"),
                                         _("Shows an in-game overlay with FPS, CPU/GPU usage, and temps."),
                                         { "mangohud" },
                                         false,
                                         LaunchLineType.WRAPPER,
                                         "performance-overlay"
            );


            steam_deck_tile = create_tile (
                _("Use desktop game profile"),
                _("Disables the Steam Deck-specific profile that some games use."),
                { "SteamDeck=0" },
                false,
                LaunchLineType.ENVIRONMENT,
                "desktop-game-profile"
            );

            wayland_tile = create_tile (
                _("Native Wayland"),
                _("Runs the game natively on Wayland instead of through XWayland but it breaks Steam Input and the Steam Overlay."),
                { "PROTON_ENABLE_WAYLAND=1" },
                false,
                LaunchLineType.ENVIRONMENT,
                "native-wayland"
            );

            gamemode_tile = create_tile (
                _("GameMode"),
                _("Requests temporary optimizations for system performance (CPU governor, process priority) when the game is running."),
                { "gamemoderun" },
                false,
                LaunchLineType.WRAPPER,
                "gamemode"
            );

            game_performance_tile = create_tile (
                _("CachyOS game-performance profile"),
                _("Uses CachyOS performance power and sched_ext gaming profiles until the game exits."),
                { "game-performance" }, false, LaunchLineType.WRAPPER, "game-performance"
            );

            mangohud_vulkan_tile = create_tile (
                _("MangoHud Vulkan environment mode"),
                _("Uses MANGOHUD=1 for Vulkan only. Prefer the MangoHud wrapper when OpenGL support is needed."),
                { "MANGOHUD=1" }, false, LaunchLineType.ENVIRONMENT, "mangohud-vulkan"
            );

            obs_vkcapture_tile = create_tile (
                _("OBS Vulkan/OpenGL capture"),
                _("Loads obs-vkcapture. Install the native package, or both the Flatpak OBS plugin and capture-tools layer."),
                { "OBS_VKCAPTURE=1" }, false, LaunchLineType.ENVIRONMENT, "obs-vkcapture"
            );

            this.add (mangohud_tile);
            this.add (steam_deck_tile);
            this.add (wayland_tile);
            this.add (gamemode_tile);
            this.add (game_performance_tile);
            this.add (mangohud_vulkan_tile);
            this.add (obs_vkcapture_tile);
        }
    }
}
