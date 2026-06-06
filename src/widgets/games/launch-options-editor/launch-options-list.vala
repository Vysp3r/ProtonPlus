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

        public string to_launch_line () {
            var segments = get_segments ();

            return string.joinv (" ", segments.to_array ());
        }

        public Gee.LinkedList<string> get_segments () {
            var segments = new Gee.LinkedList<string> ();

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
    }
}