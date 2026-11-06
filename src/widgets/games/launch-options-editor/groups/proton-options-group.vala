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

            proton_priority_high_tile = create_tile ("high-process-priority");
            proton_use_wow64_tile = create_tile ("wow64");
            proton_force_large_address_aware_tile = create_tile ("large-address-aware");
            proton_logs_tile = create_tile ("proton-debug-log");
            proton_optiscaler_tile = create_tile ("optiscaler");
            proton_discord_bridge_tile = create_tile ("discord-bridge");
            proton_use_d7vk_tile = create_tile ("d7vk");

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
