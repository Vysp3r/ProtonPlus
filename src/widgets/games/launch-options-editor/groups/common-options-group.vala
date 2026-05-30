namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class CommonOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile mangohud_tile { get; private set; }
        LaunchOptionTile steam_deck_tile { get; private set; }
        LaunchOptionTile wayland_tile { get; private set; }

        public CommonOptionsGroup (owned SimpleCallback standard_control_changed, List<ILaunchOption> launch_option_handlers) {
            base(standard_control_changed, launch_option_handlers);

            this.title = _ ("Common options");
            this.description = _ ("Quick toggles for the launch options people reach for most often.");

            mangohud_tile = create_tile (
                _ ("Performance overlay"), 
                _ ("Shows an in-game overlay with FPS, CPU/GPU usage, and temps."), 
                { "mangohud" }
            );

            if (Globals.MANGOHUD_INSTALLED) {
                Globals.SETTINGS.bind ("experimental-features", mangohud_tile, "visible", SettingsBindFlags.DEFAULT);
            } else {
                mangohud_tile.visible = false;
            }

            steam_deck_tile = create_tile(
                _ ("Disable Steam Deck Mode"), 
                _ ("Disables the Steam Deck-specific profile that some games use."),
                { "SteamDeck=0" }
            );

            wayland_tile = create_tile (
                _ ("Wayland"), 
                _ ("Runs the game natively on Wayland instead of through XWayland but it breaks Steam Input and the Steam Overlay."),
                { "PROTON_ENABLE_WAYLAND=1" }
            );

            this.add (mangohud_tile);
            this.add (steam_deck_tile);
            this.add (wayland_tile);
        }
    }
}