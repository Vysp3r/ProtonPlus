namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class AdvancedOptionsGroup : BaseOptionsGroup {
        LaunchOptionArgumentList custom_arguments;

        public AdvancedOptionsGroup (
            LaunchOptionsList launch_option_handlers,
            LaunchOptionPresentationRegistry? presentation_registry = null
        ) {
            base (launch_option_handlers, false, presentation_registry);
            this.set_margin_bottom (15);
            this.title = _("Advanced options");
            this.description = _("Extra control over the final Steam launch command.");

            custom_arguments = new LaunchOptionArgumentList (
                _("Custom game arguments"),
                _("Unknown arguments are imported here and preserved exactly as loaded.")
            );
            custom_arguments.changed.connect (() => this.changed ());
            launch_option_handlers.add (custom_arguments);
            register_option ("custom-game-arguments", custom_arguments, custom_arguments);
            this.add (custom_arguments);
        }

        public void load_custom_arguments (LaunchCommandParseResult parsed) {
            custom_arguments.load_from_parse_result (parsed);
        }
    }
}
