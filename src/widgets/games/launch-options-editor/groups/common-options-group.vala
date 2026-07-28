namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class CommonOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile mangohud_tile { get; private set; }
        LaunchOptionTile steam_deck_tile { get; private set; }
        LaunchOptionTile wayland_tile { get; private set; }
        LaunchOptionTile gamemode_tile { get; private set; }

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

            this.add (mangohud_tile);
            this.add (steam_deck_tile);
            this.add (wayland_tile);
            this.add (gamemode_tile);
        }
    }
}
