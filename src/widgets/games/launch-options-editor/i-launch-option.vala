namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    public interface ILaunchOption : Gtk.Widget {
        public abstract void parse_tokens (string[] tokens, bool[] consumed);
        public abstract void clear ();
        public abstract void append_command_segments (Gee.LinkedList<string> segments);
    }
}