namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    abstract class BaseBinding : Object {
        public LaunchLineType line_type { get; set; default = LaunchLineType.ENVIRONMENT; }
        protected Gee.List<ILaunchOption> _children;
        public bool is_advanced { get; set; default = false; }

        protected BaseBinding (bool is_advanced = false, LaunchLineType line_type = LaunchLineType.ENVIRONMENT) {
            this.is_advanced = is_advanced;
            this.line_type = line_type;
            this._children = new Gee.ArrayList<ILaunchOption> ();
        }

        public void add_child (ILaunchOption child) {
            this._children.add (child);
        }
    }
}