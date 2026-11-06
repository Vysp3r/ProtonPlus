namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GameArgumentsGroup : BaseOptionsGroup {
        LaunchOptionTile skip_launcher_tile { get; set; }
        LaunchOptionTile vulkan_tile { get; set; }
        LaunchOptionTile dx11_tile { get; set; }
        LaunchOptionTile dx12_tile { get; set; }
        LaunchOptionTile console_tile { get; set; }

        public GameArgumentsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, false, presentation_registry);

            this.title = _("Game arguments");
            this.description = _("Flags passed directly to the game.");

            skip_launcher_tile = create_tile ("skip-launcher");
            vulkan_tile = create_tile ("renderer-vulkan");
            dx11_tile = create_tile ("renderer-dx11");
            dx12_tile = create_tile ("renderer-dx12");
            console_tile = create_tile ("developer-console");

            this.add (skip_launcher_tile);
            this.add (vulkan_tile);
            this.add (dx11_tile);
            this.add (dx12_tile);
            this.add (console_tile);
        }
    }
}
