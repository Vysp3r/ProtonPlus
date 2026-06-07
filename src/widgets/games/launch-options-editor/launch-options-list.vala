namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    public class LaunchOptionsList : Object {
        private Gee.List<ILaunchOption> _options;

        public LaunchOptionsList () {
            this._options = new Gee.ArrayList<ILaunchOption> ();
        }

        public void add (ILaunchOption option) {
            this._options.add (option);
        }

        public string build_preview_markup () {
            var segments = get_segments ();
            if (segments.size == 0)
                return "<tt><span foreground='#8b949e'>%s</span></tt>".printf (Markup.escape_text (_("No launch options configured yet.")));

            string[] preview_colors = {
                "#79c0ff",
                "#ff938a",
                "#7ee787",
                "#d2a8ff",
                "#e3b341",
                "#56d4dd"
            };
            var markup = new StringBuilder ();
            markup.append ("<tt>");

            for (var index = 0; index < segments.size; index++) {
                if (index > 0)
                    markup.append (" ");

                var escaped_segment = Markup.escape_text (segments[index]);
                markup.append ("<span foreground='%s'>%s</span>".printf (preview_colors[index % preview_colors.length], escaped_segment));
            }

            markup.append ("</tt>");

            return markup.str;
        }

        public string to_launch_line () {
            var segments = get_segments ();

            return string.joinv (" ", segments.to_array ());
        }

        public Gee.LinkedList<string> get_segments () {
            var segments = new Gee.LinkedList<string> ();
            var additional_envs = new Gee.LinkedList<string> ();
            var additional_args = new Gee.LinkedList<string> ();


            foreach (var option in get_additionals ()) {
                var entry_bind = option as EntryBinding;
                if (entry_bind != null) {
                    additional_envs.add_all (entry_bind.get_env_tokens ());
                    additional_args.add_all (entry_bind.get_argument_tokens ());
                }
            }

            if (additional_envs.size > 0) {
                segments.add_all (additional_envs);
            }

            foreach (var option in get_environments ()) {
                option.append_command_segments (segments);
            }

            foreach (var option in get_wrappers ()) {
                option.append_command_segments (segments);
            }

            foreach (var option in get_commands ()) {
                option.append_command_segments (segments);
            }

            foreach (var option in get_arguments ()) {
                option.append_command_segments (segments);
            }

            if (additional_args.size > 0) {
                segments.add_all (additional_args);
            }

            return segments;
        }

        private Gee.List<ILaunchOption> get_options_by_type (LaunchLineType type) {
            var filtered = new Gee.ArrayList<ILaunchOption> ();
            foreach (var option in this._options) {
                if (option.line_type == type) {
                    filtered.add (option);
                }
            }
            return filtered;
        }

        public Gee.List<ILaunchOption> get_additionals () {
            return this.get_options_by_type (LaunchLineType.ADDITIONAL);
        }

        public Gee.List<ILaunchOption> get_environments () {
            return this.get_options_by_type (LaunchLineType.ENVIRONMENT);
        }

        public Gee.List<ILaunchOption> get_wrappers () {
            return this.get_options_by_type (LaunchLineType.WRAPPER);
        }

        public Gee.List<ILaunchOption> get_commands () {
            return this.get_options_by_type (LaunchLineType.COMMAND);
        }

        public Gee.List<ILaunchOption> get_arguments () {
            return this.get_options_by_type (LaunchLineType.ARGUMENT);
        }

        public void clear_all () {
            foreach (var option in this._options) {
                option.clear ();
            }
        }

        public void parse_all_tokens (string[] tokens_pool, bool[] consumed) {
            foreach (var option in this._options) {
                option.parse_tokens (tokens_pool, consumed);
            }
        }

        public Gee.Iterator<ILaunchOption> iterator () {
            return this._options.iterator ();
        }

        public string[] get_launch_option_tokens (string launch_options) {
            return normalize_launch_options (launch_options).split (" ");
        }

        public bool load_from_string (string launch_options) {
            this.clear_all ();

            var tokens = this.get_launch_option_tokens (launch_options);
            var consumed = new bool[tokens.length];

            this.parse_all_tokens (tokens, consumed);

            for (var i = 0; i < tokens.length; i++) {
                if (tokens[i] == "%command%") {
                    consumed[i] = true;
                    break;
                }
            }

            foreach (var option in this._options) {
                if (option.is_advanced && option.is_active ()) {
                    return true;
                }
            }

            return false;
        }

        string normalize_launch_options (string launch_options) {
            var output = new StringBuilder ();

            foreach (var token in launch_options.strip ().split (" ")) {
                if (token == "")
                    continue;

                append_token (output, token);
            }

            return output.str;
        }

        void append_token (StringBuilder output, string token) {
            if (output.len > 0)
                output.append (" ");

            output.append (token);
        }
    }
}