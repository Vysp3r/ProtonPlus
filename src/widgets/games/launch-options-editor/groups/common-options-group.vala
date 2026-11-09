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

            mangohud_tile = create_tile ("performance-overlay");


            steam_deck_tile = create_tile ("desktop-game-profile");

            wayland_tile = create_tile ("native-wayland");

            gamemode_tile = create_tile ("gamemode");

            game_performance_tile = create_tile ("game-performance");

            mangohud_vulkan_tile = create_tile ("mangohud-vulkan");

            obs_vkcapture_tile = create_tile ("obs-vkcapture");

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
