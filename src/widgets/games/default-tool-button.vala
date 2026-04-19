namespace ProtonPlus.Widgets {
    public class DefaultToolButton : Gtk.Button {
        public signal void default_tool_requested (Models.Launchers.Steam launcher);

        Models.Launchers.Steam launcher { get; set; }

        construct {
            clicked.connect (default_tool_button_clicked);

            set_label (_ ("Set the default compatibility tool"));
        }

        public void load (Models.Launchers.Steam launcher) {
            this.launcher = launcher;
        }

        void default_tool_button_clicked () {
            if (launcher == null)
            return;

            default_tool_requested (launcher);
        }
    }
}
