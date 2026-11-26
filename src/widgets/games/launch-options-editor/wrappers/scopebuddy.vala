namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public class Scopebuddy : Base {
        protected override string backend_id { get { return "scopebuddy"; } }

        LaunchOptionEntryField args_field;
        Gtk.Widget cached_page;

        public Scopebuddy (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, presentation_registry);
        }

        public Gtk.Widget create_page () {
            if (cached_page != null)
                return cached_page;

            var group = new Adw.PreferencesGroup ();
            group.add (create_value_field ("scopebuddy-profile"));
            group.add (create_value_field ("scopebuddy-app-id"));
            group.add (create_boolean_choice ("scopebuddy-environment-only"));
            group.add (create_tile ("scopebuddy-fullscreen", true));
            group.add (create_resolution_tile ("scopebuddy-resolution", true, true));
            group.add (create_tile ("scopebuddy-auto-hdr", true));
            group.add (create_tile ("scopebuddy-auto-vrr", true));
            group.add (create_boolean_choice ("scopebuddy-auto-refresh"));
            group.add (create_boolean_choice ("scopebuddy-auto-frame-limit"));
            group.add (create_number_tile ("scopebuddy-frame-limit", _("Hz")));
            group.add (create_number_tile ("scopebuddy-fps-limit", _("FPS")));
            group.add (create_choice_tile ("scopebuddy-append-mode", {
                _("Use profile setting"), _("Use configured arguments as fallback"), _("Append launch arguments")
            }));
            group.add (create_boolean_choice ("scopebuddy-debug"));

            args_field = new LaunchOptionEntryField (
                _("Additional ScopeBuddy arguments"),
                _("Keeps extra ScopeBuddy flags such as preferred output selection."),
                _("Add ScopeBuddy arguments")
            );
            register_option ("scopebuddy-arguments", args_field);
            args_field.changed.connect (() => {
                this.changed ();
            });

            group.add (args_field);
            group.add (args_field.validation_label);

            cached_page = group;
            return group;
        }

        LaunchOptionEnvCombo create_boolean_choice (string id) {
            return create_choice_tile (id, { _("Use profile setting"), _("Disabled"), _("Enabled") });
        }

        internal void set_raw_arguments (string arguments) {
            args_field.text = arguments;
        }

        public override void clear () {
            foreach (var child in this._children) {
                child.clear ();
            }

            args_field.set_text ("");
        }

        public override void parse_tokens (string[] tokens, bool[] consumed) {}

        public override void append_command_segments (Gee.LinkedList<string> segments) {
            if (!this.is_active ())
                return;

            segments.add ("scopebuddy");

            foreach (var child in this._children) {
                if (child.is_active ()) {
                    child.append_command_segments (segments);
                }
            }
            segments.add ("--");
        }
    }
}
