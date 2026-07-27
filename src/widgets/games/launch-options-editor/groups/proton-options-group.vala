namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class ProtonOptionsGroup : BaseOptionsGroup {

        LaunchOptionTile proton_priority_high_tile { get; private set; }
        LaunchOptionTile proton_use_wow64_tile { get; private set; }
        LaunchOptionTile proton_force_large_address_aware_tile { get; private set; }
        LaunchOptionTile proton_logs_tile { get; private set; }
        LaunchOptionTile proton_optiscaler_tile { get; private set; }
        LaunchOptionTile proton_discord_bridge_tile { get; private set; }
        LaunchOptionTile proton_use_d7vk_tile { get; private set; }
        LaunchOptionDllOverrides dll_overrides_pair_editor { get; private set; }

        public ProtonOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, false, presentation_registry);

            this.title = _("Proton options");
            this.description = _("Extra Proton settings and launch behaviors.");

            proton_priority_high_tile = create_tile (
                _("High process priority"),
                _("Gives the game a higher CPU priority which can improve performance in some cases."),
                { "PROTON_PRIORITY_HIGH=1" }, false, LaunchLineType.ENVIRONMENT, "high-process-priority"
            );
            proton_use_wow64_tile = create_tile (
                _("WoW64 mode"),
                _("Enables WoW64 support for 32-bit games on 64-bit Proton builds. This can improve compatibility for some older games."),
                { "PROTON_USE_WOW64=1" }, false, LaunchLineType.ENVIRONMENT, "wow64"
            );
            proton_force_large_address_aware_tile = create_tile (
                _("Large address awareness for 32-bit games"),
                _("Forces 32-bit games to use large address aware which can improve performance and stability."),
                { "PROTON_FORCE_LARGE_ADDRESS_AWARE=1" }, false, LaunchLineType.ENVIRONMENT, "large-address-aware"
            );
            proton_logs_tile = create_tile (
                _("Proton debug log"),
                _("Enables logging for Proton which can help with troubleshooting game issues. Logs are saved in the game's compatibility data folder."),
                { "PROTON_LOG=1" }, false, LaunchLineType.ENVIRONMENT, "proton-debug-log"
            );
            proton_optiscaler_tile = create_tile (
                _("OptiScaler integration"),
                _("Enables the Proton OptiScaler which can improve performance and image quality for some games (Available from version 11-1)."),
                { "PROTON_USE_OPTISCALER=1" }, false, LaunchLineType.ENVIRONMENT, "optiscaler"
            );
            proton_discord_bridge_tile = create_tile (
                _("Discord bridge"),
                _("Enables the Proton Discord Bridge which can improve integration with Discord for some games (Available from version 11-1)."),
                { "PROTON_DISCORD_BRIDGE=1" }, false, LaunchLineType.ENVIRONMENT, "discord-bridge"
            );
            proton_use_d7vk_tile = create_tile (
                _("Use D7VK"),
                _("Enables the use of D7VK which can improve performance and compatibility for some Direct3D 9 games (Available from version 11-1)."),
                { "PROTON_USE_D7VK=1" }, false, LaunchLineType.ENVIRONMENT, "d7vk"
            );

            // DLL overrides
            dll_overrides_pair_editor = new LaunchOptionDllOverrides ();
            dll_overrides_pair_editor.changed.connect ((row) => {
                this.changed ();
            });

            this.add (proton_priority_high_tile);
            this.add (proton_use_wow64_tile);
            this.add (proton_force_large_address_aware_tile);
            this.add (proton_logs_tile);
            this.add (proton_optiscaler_tile);
            this.add (proton_discord_bridge_tile);
            this.add (proton_use_d7vk_tile);
            this.add (dll_overrides_pair_editor);

            launch_option_handlers.add (dll_overrides_pair_editor);
            register_option ("dll-overrides", dll_overrides_pair_editor, dll_overrides_pair_editor);
        }
    }
}
