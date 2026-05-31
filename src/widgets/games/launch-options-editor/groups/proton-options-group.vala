namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class ProtonOptionsGroup : BaseOptionsGroup {

        LaunchOptionTile proton_priority_high_tile { get; private set; }
        LaunchOptionTile proton_use_wow64_tile { get; private set; }
        LaunchOptionTile proton_force_large_address_aware_tile { get; private set; }
        LaunchOptionTile proton_logs_tile { get; private set; }
        LaunchOptionDllOverrides dll_overrides_pair_editor { get; private set; }

        public ProtonOptionsGroup (owned SimpleCallback standard_control_changed, List<ILaunchOption> launch_option_handlers) {
            base(standard_control_changed, launch_option_handlers);

            this.title = _ ("Proton options");
            this.description = _ ("Extra Proton settings and launch behaviors.");

            proton_priority_high_tile = create_tile (_ ("Higher priority for games"), _ ("Gives the game a higher CPU priority which can improve performance in some cases."), { "PROTON_PRIORITY_HIGH=1" });
            proton_use_wow64_tile = create_tile (_ ("Use WoW64"), _ ("Enables WoW64 support for 32-bit games on 64-bit Proton builds. This can improve compatibility for some older games."), { "PROTON_USE_WOW64=1" });
            proton_force_large_address_aware_tile = create_tile (_ ("Allows 32-bit games to use more than 2GB of RAM"), _ ("Forces 32-bit games to use large address aware which can improve performance and stability."), { "PROTON_FORCE_LARGE_ADDRESS_AWARE=1" });
            proton_logs_tile = create_tile (_ ("Enable Proton logs"), _ ("Enables logging for Proton which can help with troubleshooting game issues. Logs are saved in the game's compatibility data folder."), { "PROTON_LOG=1" });

            // DLL overrides
            dll_overrides_pair_editor = new LaunchOptionDllOverrides ();
            dll_overrides_pair_editor.changed.connect ((row) => {
                standard_control_changed ();
            });

            this.add(proton_priority_high_tile);
            this.add(proton_use_wow64_tile);
            this.add(proton_force_large_address_aware_tile);
            this.add(proton_logs_tile);
            this.add(dll_overrides_pair_editor);

            launch_option_handlers.append (dll_overrides_pair_editor);
        }
    }
}
