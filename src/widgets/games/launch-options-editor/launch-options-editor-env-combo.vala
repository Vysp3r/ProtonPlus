namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
using Gtk;

    public class LaunchOptionEnvCombo : ComboRow {
        public string environment_variable { get; protected set; }
        public string environment_variable_prefix { get; protected set; }

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
            this.value_opts = value_opts;

            this.title = title_text;
            this.subtitle = subtitle_text;

            var string_list = new Gtk.StringList (display_opts);
            this.model = string_list;

            this.notify["selected"].connect (() => {
                this.changed ();
            });
        }

        public void set_current_value (string current_env_string) {
            if (current_env_string.has_prefix (environment_variable_prefix)) {
                this.value = current_env_string.split ("=")[1];
            } else {
                this.value = "";
            }
        }
    }
}