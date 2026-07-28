namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {

    /*
     * These types describe already serialized shell segments.  They do not
     * parse, quote, or otherwise interpret launch-option text.
     */
    public class LaunchEnvironmentAssignment : Object {
        public string key { get; construct; }
        public string raw_assignment { get; construct; }

        public LaunchEnvironmentAssignment (string key, string raw_assignment) {
            Object (key: key, raw_assignment: raw_assignment);
        }
    }

    public class LaunchWrapperInvocation : Object {
        public string id { get; construct; }
        public string[] executable_tokens { get; construct; }
        public string[] argument_tokens { get; construct; }
        public string? delimiter { get; construct; }
        public int nesting_priority { get; construct; }

        public LaunchWrapperInvocation (
            string id,
            string[] executable_tokens,
            string[] argument_tokens = {},
            string? delimiter = null,
            int nesting_priority = 0
        ) {
            Object (
                id: id,
                executable_tokens: executable_tokens,
                argument_tokens: argument_tokens,
                delimiter: delimiter,
                nesting_priority: nesting_priority
            );
        }
    }

    public class LaunchCommandPlan : Object {
        public LaunchEnvironmentAssignment[] environment_assignments;
        public LaunchWrapperInvocation[] wrappers;
        public string[] game_arguments { get; private set; }
        public bool retain_placeholder_for_arguments_only { get; private set; }

        public LaunchCommandPlan (
            LaunchEnvironmentAssignment[] environment_assignments = {},
            LaunchWrapperInvocation[] wrappers = {},
            string[] game_arguments = {},
            bool retain_placeholder_for_arguments_only = false
        ) {
            this.environment_assignments = environment_assignments;
            this.wrappers = wrappers;
            this.game_arguments = game_arguments;
            this.retain_placeholder_for_arguments_only = retain_placeholder_for_arguments_only;
        }
    }
}
