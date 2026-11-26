using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GameArgumentsGroup : BaseOptionsGroup {
        LaunchOptionTile skip_launcher_tile { get; set; }
        LaunchOptionTile vulkan_tile { get; set; }
        LaunchOptionTile dx11_tile { get; set; }
        LaunchOptionTile dx12_tile { get; set; }
        LaunchOptionTile console_tile { get; set; }
        LaunchCustomWrapperField custom_wrapper;
        LaunchOptionEnvCombo native_wrapper;
        LaunchCommandCapabilityContext? capabilities;

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

            var catalog = presentation_registry?.catalog ?? new LaunchOptionCatalog ();
            var native_metadata = catalog.lookup ("native-game-wrapper");
            native_wrapper = new LaunchOptionEnvCombo ("", native_metadata.title, native_metadata.description,
                { _("None") }, { "" });
            native_wrapper.line_type = LaunchLineType.WRAPPER;
            native_wrapper.changed.connect (() => changed ());
            launch_option_handlers.add (native_wrapper);
            register_option (native_metadata.id, native_wrapper, native_wrapper);
            add (native_wrapper);

            var wrapper_id = LaunchCustomWrapperInput.OPTION_ID;
            custom_wrapper = new LaunchCustomWrapperField (catalog.lookup (wrapper_id));
            custom_wrapper.changed.connect (() => this.changed ());
            launch_option_handlers.add (custom_wrapper);
            register_option (wrapper_id, custom_wrapper, custom_wrapper);
            this.add (custom_wrapper);
        }

        internal void load_from_parse_result (LaunchCommandParseResult parsed) {
            custom_wrapper.load_from_parse_result (parsed);
            var selected = "";
            foreach (var occurrence in parsed.occurrences) {
                if (occurrence.option_id == "native-game-wrapper") {
                    selected = occurrence.wrapper_id;
                    break;
                }
            }
            refresh_native_wrappers (selected);
        }

        internal void set_capability_context (LaunchCommandCapabilityContext? context) {
            capabilities = context;
            refresh_native_wrappers (native_wrapper.value);
        }

        void refresh_native_wrappers (string selected) {
            var labels = new Gee.ArrayList<string> ();
            var values = new Gee.ArrayList<string> ();
            labels.add (_("None"));
            values.add ("");
            if (selected == "tinkergame" || (capabilities != null && capabilities.has (LaunchOptionCapability.TINKERGAME))) {
                labels.add ("TinkerGame");
                values.add ("tinkergame");
            }
            if (selected == "steamtinkerlaunch" || (capabilities != null && capabilities.has (LaunchOptionCapability.STEAMTINKERLAUNCH))) {
                labels.add ("SteamTinkerLaunch");
                values.add ("steamtinkerlaunch");
            }
            native_wrapper.set_choices (labels.to_array (), values.to_array (), selected);
        }
    }
}
