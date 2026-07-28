namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class AdvancedOptionsGroup : BaseOptionsGroup {
        LaunchOptionEntryField additional_args_field { get; set; }
        LaunchOptionTile additional_args_tile { get; set; }
        public ILaunchOption raw_arguments_binding { get; private set; }
        bool refreshing_controls;

        public AdvancedOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, false, presentation_registry);
            refreshing_controls = true;
            this.set_margin_bottom (15);
            this.title = _("Advanced options");
            this.description = _("Extra control over the final Steam launch command.");

            additional_args_field = new LaunchOptionEntryField (_("Additional arguments"), "", _("Add extra launch options"));
            additional_args_field.value_applied.connect (() => {
                this.changed ();
            });

            additional_args_tile = create_tile (_("Custom game arguments"), _("Add your own launch options."), { "" }, false, LaunchLineType.ARGUMENT, "custom-game-arguments");
            additional_args_tile.toggle.notify["active"].connect (() => {
                additional_args_toggle_changed ();
            });

            var add_bind = new EntryBinding (additional_args_field, additional_args_tile.toggle);
            launch_option_handlers.add (add_bind);
            register_option ("custom-game-arguments", additional_args_field, add_bind);
            raw_arguments_binding = add_bind;

            this.add (additional_args_tile);
            this.add (additional_args_field);

            additional_args_field.sensitive = additional_args_tile.toggle.get_active ();
            refreshing_controls = false;
        }

        void additional_args_toggle_changed () {
            if (refreshing_controls)
                return;

            bool is_active = additional_args_tile.toggle.get_active ();

            if (is_active) {
                additional_args_field.sensitive = true;
                additional_args_field.focus_entry ();
            } else {
                additional_args_tile.toggle.grab_focus ();
                additional_args_field.sensitive = false;
                // additional_args_field.set_text ("");
            }
            this.changed ();
        }
    }
}
