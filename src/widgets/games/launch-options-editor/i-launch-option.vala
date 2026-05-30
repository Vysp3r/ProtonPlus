namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    public interface ILaunchOption : Object {
        public abstract void parse_tokens (string[] tokens, bool[] consumed);
        public abstract void clear ();
        public abstract void append_command_segments (Gee.LinkedList<string> segments);
        public abstract bool is_advanced { get; set; }
        public abstract bool is_active ();
    }
}