namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GameArgumentsGroup : BaseOptionsGroup {
        LaunchOptionTile skip_launcher_tile { get; set; }
        LaunchOptionTile vulkan_tile { get; set; }
        LaunchOptionTile dx11_tile { get; set; }
        LaunchOptionTile dx12_tile { get; set; }
        LaunchOptionTile console_tile { get; set; }

        public GameArgumentsGroup (owned SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            base (standard_control_changed, launch_option_handlers);

            this.title = _("Game arguments");
            this.description = _("Flags passed directly to the game.");

            skip_launcher_tile = create_game_argument_tile (_("Skip launcher"), _("Adds -skip-launcher to bypass launchers in games that support it."), { "-skip-launcher" });
            vulkan_tile = create_game_argument_tile (_("Vulkan"), _("Adds -vulkan to make the game use its Vulkan renderer."), { "-vulkan" });
            dx11_tile = create_game_argument_tile (_("DirectX 11"), _("Adds -dx11 to make the game use its DirectX 11 renderer."), { "-dx11" });
            dx12_tile = create_game_argument_tile (_("DirectX 12"), _("Adds -dx12 to make the game use its DirectX 12 renderer."), { "-dx12" });
            console_tile = create_game_argument_tile (_("Console"), _("Adds -console to open the game's developer console when supported."), { "-console" });

            this.add (skip_launcher_tile);
            this.add (vulkan_tile);
            this.add (dx11_tile);
            this.add (dx12_tile);
            this.add (console_tile);
        }
    }
}