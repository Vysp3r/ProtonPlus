namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {

    public enum LaunchLineType {
        ENVIRONMENT,
        WRAPPER,
        WRAPPER_ARGUMENT,
        COMMAND,
        ARGUMENT
    }

    public interface ILaunchOption : Object {
        public abstract LaunchLineType line_type { get; set; }
        public abstract void add_child (ILaunchOption child);
        public abstract void parse_tokens (string[] tokens, bool[] consumed);
        public abstract void clear ();
        public abstract void append_command_segments (Gee.LinkedList<string> segments);
        public abstract bool is_advanced { get; set; }
        public abstract bool is_active ();
    }
}