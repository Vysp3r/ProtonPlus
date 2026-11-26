namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class ProtonOptionsGroup : BaseOptionsGroup {

        LaunchOptionTile proton_priority_high_tile { get; private set; }
        LaunchOptionTile proton_discord_bridge_tile { get; private set; }
        LaunchOptionTile proton_use_d7vk_tile { get; private set; }
        LaunchOptionDllOverrides dll_overrides_pair_editor { get; private set; }

        public ProtonOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, false, presentation_registry);

            this.title = _("Proton options");
            this.description = _("Extra Proton settings and launch behaviors.");

            proton_priority_high_tile = create_tile ("high-process-priority");
            proton_discord_bridge_tile = create_tile ("discord-bridge");
            proton_use_d7vk_tile = create_tile ("d7vk");

            // DLL overrides
            dll_overrides_pair_editor = new LaunchOptionDllOverrides ();
            dll_overrides_pair_editor.changed.connect ((row) => {
                this.changed ();
            });

            this.add (proton_priority_high_tile);
            add (create_environment_combo ("large-address-aware", { _("Off"), _("On") }));
            add (create_environment_field ("proton-debug-log"));
            add (create_environment_field ("proton-log-directory"));
            add (create_tile ("proton-esync"));
            add (create_tile ("proton-fsync"));
            add (create_tile ("proton-no-d3d11"));
            add (create_tile ("proton-no-d3d10"));
            add (create_tile ("proton-disable-nvapi"));
            this.add (proton_discord_bridge_tile);
            this.add (proton_use_d7vk_tile);
            add (create_environment_combo ("wow64", { _("Off"), _("On") }));
            add (create_environment_field ("optiscaler"));
            add (create_environment_combo ("proton-hevc-defaults", { _("Off"), _("On") }));
            add (create_environment_field ("proton-hevc-renderer"));
            add (create_environment_combo ("proton-tkg-nvapi", { _("On"), _("Off") }));
            add (create_environment_combo ("proton-tkg-winedbg", { _("On"), _("Off") }));
            add (create_environment_combo ("proton-tkg-pulse", { _("Off"), _("On") }));
            add (create_environment_combo ("proton-tkg-d3d9", { _("Off"), _("On") }));
            add (create_environment_combo ("proton-tkg-winetricks", { _("Off"), _("On") }));
            foreach (var id in new string[] {
                "proton-anime-xxmi", "proton-anime-gimi", "proton-anime-srmi", "proton-anime-zzmi",
                "proton-anime-himi", "proton-anime-wwmi", "proton-anime-efmi", "proton-anime-reshade",
                "proton-anime-reshade-path", "proton-anime-hsr-fps", "proton-anime-gi-fps",
                "proton-anime-nte-timeout", "proton-anime-wuwa-engine",
                "boxtron-sierra-game", "roberta-scummvm-command", "roberta-screen"
            })
                add (create_environment_field (id));
            add (create_tile ("proton-anime-kuro"));
            add (create_tile ("proton-anime-nte"));
            add (create_environment_combo ("luxtorpeda-confirm", { _("Ask for confirmation"), _("Skip confirmation") }));
            add (create_environment_combo ("luxtorpeda-logging", { _("Off"), _("On") }));
            add (create_tile ("luxtorpeda-cloud"));
            add (create_environment_combo ("rosemary-glibc", { _("Automatic"), _("Host"), _("Bundled") }));
            add (create_tile ("rosemary-trace"));
            this.add (dll_overrides_pair_editor);

            launch_option_handlers.add (dll_overrides_pair_editor);
            register_option ("dll-overrides", dll_overrides_pair_editor, dll_overrides_pair_editor);
        }
    }
}
