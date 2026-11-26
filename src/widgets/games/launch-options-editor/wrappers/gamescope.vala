namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public class Gamescope : Base {
        protected override string backend_id { get { return "gamescope"; } }

        LaunchOptionEntryField args_field;
        Gtk.Widget cached_page;

        public Gamescope (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, presentation_registry);
        }

        public Gtk.Widget create_page () {
            if (cached_page != null)
                return cached_page;

            var group = new Adw.PreferencesGroup ();
            group.add (create_tile ("gamescope-fullscreen", true));
            group.add (create_resolution_tile ("gamescope-resolution"));
            group.add (create_resolution_tile ("gamescope-internal-resolution"));
            group.add (create_number_tile ("gamescope-frame-limit", _("Hz")));
            group.add (create_number_tile ("gamescope-fps-limit", _("FPS")));
            group.add (create_choice_tile ("gamescope-scaler", {
                _("Default"), _("Automatic"), _("Integer"), _("Fit"), _("Fill"), _("Stretch")
            }));
            group.add (create_choice_tile ("gamescope-filter", {
                _("Default"), _("Linear"), _("Nearest"), "FSR", "NIS", _("Pixel")
            }));
            group.add (create_number_tile ("gamescope-sharpness", "", 20, 0));
            group.add (create_value_field ("gamescope-prefer-output"));
            group.add (create_number_tile ("gamescope-display-index", "", int.MAX, 0));
            group.add (create_tile ("gamescope-force-grab-cursor"));
            group.add (create_number_tile ("gamescope-hide-cursor-delay", _("ms"), int.MAX, 0));
            group.add (create_tile ("gamescope-vrr", true));
            group.add (create_tile ("gamescope-hdr", true));
            group.add (create_number_tile ("gamescope-hdr-sdr-nits", _("nits"), int.MAX, 400));
            group.add (create_tile ("gamescope-hdr-itm"));
            group.add (create_number_tile ("gamescope-hdr-itm-sdr-nits", _("nits"), 1000, 100));
            group.add (create_number_tile ("gamescope-hdr-itm-target-nits", _("nits"), 10000, 1000));
            group.add (create_tile ("gamescope-mangoapp"));

            args_field = new LaunchOptionEntryField (
                _("Additional Gamescope arguments"),
                _("Keeps extra Gamescope flags such as output or resolution tweaks."),
                _("Add Gamescope arguments")
            );
            register_option ("gamescope-arguments", args_field);
            args_field.changed.connect (() => {
                this.changed ();
            });

            group.add (args_field);
            group.add (args_field.validation_label);

            cached_page = group;
            return group;
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

            segments.add ("gamescope");

            foreach (var child in this._children) {
                if (child.is_active ()) {
                    child.append_command_segments (segments);
                }
            }
            segments.add ("--");
        }
    }
}
