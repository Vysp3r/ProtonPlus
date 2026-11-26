using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
using Gtk;

    public class LaunchOptionEnvCombo : ComboRow, ILaunchOption {
        public string environment_variable { get; protected set; }
        public string environment_variable_prefix { get; protected set; }
        public bool is_advanced { get; set; default = false; }
        public LaunchLineType line_type { get; set; default = LaunchLineType.ENVIRONMENT; }
        private Gee.List<ILaunchOption> _children;

        protected string[] value_opts;

        public new signal void changed ();

        public string value {
            get {
                uint idx = this.selected;
                if (idx < value_opts.length) {
                    return value_opts[idx];
                }
                return "";
            }
            set {
                for (uint i = 0; i < value_opts.length; i++) {
                    if (value_opts[i] == value) {
                        this.selected = i;
                        return;
                    }
                }
                this.selected = 0;
            }
        }

        public LaunchOptionEnvCombo (string env_var, string title_text, string subtitle_text, string[] display_opts, string[] value_opts) {
            this.environment_variable = env_var;
            this.environment_variable_prefix = env_var + "=";
            this._children = new Gee.ArrayList<ILaunchOption> ();

            this.title = title_text;
            this.subtitle = subtitle_text;
            this.set_tooltip_text (subtitle_text);

            set_choices (display_opts, value_opts, "");

            this.notify["selected"].connect (() => {
                this.changed ();
            });
        }

        internal void set_choices (string[] labels, string[] values, string selected_value) {
            value_opts = values;
            model = new Gtk.StringList (labels);
            value = selected_value;
        }

        internal void set_selection_editable (bool editable) {
            var can_open = editable && value_opts.length > 1;
            if (activatable == can_open)
                return;

            activatable = can_open;
            if (!can_open) {
                var focused = get_root ()?.get_focus ();
                var popover = focused?.get_ancestor (typeof (Gtk.Popover)) as Gtk.Popover;
                if (popover != null && popover.is_ancestor (this))
                    popover.popdown ();
            }
        }

        public override void activate () {
            if (activatable)
                base.activate ();
        }

        public void parse_tokens (string[] tokens, bool[] consumed) {
            if (tokens.length != consumed.length) {
                return;
            }

            for (int i = 0; i < tokens.length; i++) {
                if (consumed[i]) {
                    continue;
                }

                string token = tokens[i];
                if (token.has_prefix (this.environment_variable_prefix)) {
                    this.value = token.substring (this.environment_variable_prefix.length);

                    consumed[i] = true;
                    break;
                }
            }


            foreach (var child in this._children) {
                child.parse_tokens (tokens, consumed);
            }
        }

        public void clear () {
            this.value = "";
            foreach (var child in this._children) {
                child.clear ();
            }
        }

        public void add_child (ILaunchOption child) {
            this._children.add (child);
        }

        public virtual void append_command_segments (Gee.LinkedList<string> segments) {
            string val = this.value;
            if (val != "") {
                segments.add (this.environment_variable_prefix + val);
                foreach (var child in this._children) {
                    if (child.is_active ()) {
                        child.append_command_segments (segments);
                    }
                }
            }
        }

        public bool is_active () {
            return this.value != "";
        }
    }
}
