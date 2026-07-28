namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    public class LaunchCommandBuildResult : Object {
        public bool is_valid { get; construct; }
        public Gee.List<string> segments { get; construct; }
        public Gee.List<string> errors { get; construct; }
        public string launch_line { get; construct; }

        public LaunchCommandBuildResult (
            bool is_valid,
            Gee.List<string> segments,
            Gee.List<string> errors
        ) {
            Object (
                is_valid: is_valid,
                segments: segments,
                errors: errors,
                launch_line: is_valid ? string.joinv (" ", segments.to_array ()) : ""
            );
        }
    }

    public class LaunchCommandBuilder : Object {
        const string COMMAND_PLACEHOLDER = "%command%";

        public LaunchCommandBuildResult build (LaunchCommandPlan plan) {
            var errors = validate (plan);
            var segments = new ArrayList<string> ();
            if (errors.size > 0)
                return new LaunchCommandBuildResult (false, segments, errors);

            foreach (var environment in plan.environment_assignments)
                segments.add (environment.raw_assignment);

            var wrappers = get_ordered_wrappers (plan.wrappers);
            foreach (var wrapper in wrappers) {
                append_tokens (segments, wrapper.executable_tokens);
                append_tokens (segments, wrapper.argument_tokens);
                if (wrapper.delimiter != null)
                    segments.add (wrapper.delimiter);
            }

            if (requires_placeholder (plan))
                segments.add (COMMAND_PLACEHOLDER);

            append_tokens (segments, plan.game_arguments);
            return new LaunchCommandBuildResult (true, segments, errors);
        }

        bool requires_placeholder (LaunchCommandPlan plan) {
            return plan.environment_assignments.length > 0
                   || plan.wrappers.length > 0
                   || plan.retain_placeholder_for_arguments_only;
        }

        ArrayList<LaunchWrapperInvocation> get_ordered_wrappers (LaunchWrapperInvocation[] wrappers) {
            var ordered = new ArrayList<LaunchWrapperInvocation> ();
            foreach (var wrapper in wrappers)
                ordered.add (wrapper);
            ordered.sort ((first, second) => {
                if (first.nesting_priority != second.nesting_priority)
                    return first.nesting_priority - second.nesting_priority;
                return strcmp (first.id, second.id);
            });
            return ordered;
        }

        ArrayList<string> validate (LaunchCommandPlan plan) {
            var errors = new ArrayList<string> ();
            var environment_keys = new HashSet<string> ();
            var priorities = new HashSet<int> ();

            foreach (var environment in plan.environment_assignments) {
                if (environment.key.strip () == "")
                    errors.add ("Environment assignments require a key.");
                else if (environment_keys.contains (environment.key))
                    errors.add ("Duplicate environment key: %s".printf (environment.key));
                else
                    environment_keys.add (environment.key);

                validate_token (errors, environment.raw_assignment, "environment assignment");
            }

            foreach (var wrapper in plan.wrappers) {
                if (wrapper.id.strip () == "")
                    errors.add ("Wrapper definitions require an ID.");
                if (wrapper.executable_tokens.length == 0)
                    errors.add ("Wrapper '%s' requires an executable token.".printf (wrapper.id));
                if (priorities.contains (wrapper.nesting_priority))
                    errors.add ("Wrapper nesting priority %d is ambiguous.".printf (wrapper.nesting_priority));
                else
                    priorities.add (wrapper.nesting_priority);

                foreach (var token in wrapper.executable_tokens)
                    validate_token (errors, token, "wrapper executable token");
                foreach (var token in wrapper.argument_tokens)
                    validate_token (errors, token, "wrapper argument");
                if (wrapper.delimiter != null)
                    validate_token (errors, wrapper.delimiter, "wrapper delimiter");
            }

            foreach (var argument in plan.game_arguments)
                validate_token (errors, argument, "game argument");

            return errors;
        }

        void validate_token (ArrayList<string> errors, string token, string description) {
            if (token.strip () == "")
                errors.add ("%s must not be empty.".printf (description));
            if (token.contains (COMMAND_PLACEHOLDER))
                errors.add ("%s must not contain %s.".printf (description, COMMAND_PLACEHOLDER));
        }

        void append_tokens (ArrayList<string> segments, string[] tokens) {
            foreach (var token in tokens)
                segments.add (token);
        }
    }
}
