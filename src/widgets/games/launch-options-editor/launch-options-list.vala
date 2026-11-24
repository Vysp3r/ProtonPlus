using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    // Controls parse source words; LaunchCommandWriter owns command serialization.
    public class LaunchOptionsList : Object {
        private Gee.List<ILaunchOption> _options;

        public LaunchOptionsList () {
            this._options = new Gee.ArrayList<ILaunchOption> ();
        }

        public void add (ILaunchOption option) {
            this._options.add (option);
        }

        /* Display markup only. The exact command is still produced
         * exclusively by LaunchCommandWriter before reaching this formatter. */
        public static string build_command_preview_markup (string command) {
            if (command == "")
                return Markup.escape_text (_("No launch options configured yet."));
            return "<tt>%s</tt>".printf (Markup.escape_text (command));
        }

        public static string build_labeled_command_preview_markup (string[] labels, string[] commands) {
            assert (labels.length == commands.length);
            var markup = new StringBuilder ();
            for (var index = 0; index < commands.length; index++) {
                if (index > 0)
                    markup.append ("\n\n");
                markup.append ("<b>%s</b>\n".printf (Markup.escape_text (labels[index])));
                markup.append (build_command_preview_markup (commands[index]));
            }
            return markup.str;
        }

        public void clear_all () {
            foreach (var option in this._options) {
                option.clear ();
            }
        }

        public Gee.Iterator<ILaunchOption> iterator () {
            return this._options.iterator ();
        }

        public string[] get_launch_option_tokens (string launch_options) {
            var values = new Gee.ArrayList<string> ();
            foreach (var token in new LaunchOptionShellTokenizer ().tokenize (launch_options)) {
                if (!token.is_opaque)
                    values.add (token.value);
            }
            return values.to_array ();
        }

        public bool load_from_string (string launch_options) {
            this.clear_all ();
            var tokens = get_launch_option_tokens (launch_options);
            var consumed = new bool[tokens.length];
            foreach (var option in this._options)
                option.parse_tokens (tokens, consumed);

            foreach (var option in this._options) {
                if (option.is_advanced && option.is_active ())
                    return true;
            }
            return false;
        }
    }
}
