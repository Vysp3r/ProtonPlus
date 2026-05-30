namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public delegate void SimpleCallback ();

    public class BaseOptionsGroup : PreferencesGroup {
        protected unowned SimpleCallback standard_control_changed;
        protected unowned List<ILaunchOption> launch_option_handlers;

        internal bool is_advanced_group { get; set; default = false; }

        public BaseOptionsGroup(owned SimpleCallback standard_control_changed, List<ILaunchOption> launch_option_handlers, bool is_advanced_group = false) {
            this.standard_control_changed = standard_control_changed;
            this.launch_option_handlers = launch_option_handlers;
            this.is_advanced_group = is_advanced_group;
        }

        internal LaunchOptionTile create_tile(string title, string subtitle, string[] tokens, bool is_advanced = false) {
            var tile = new LaunchOptionTile (title, subtitle);
            tile.toggle.notify["active"].connect (() => {
                this.standard_control_changed();
            });

            this.launch_option_handlers.append(
                new LaunchOptionBinding (tokens, tile.toggle, is_advanced)
            );

            return tile;
        }

        public virtual bool has_advanced_active () {
            return false;
        }
    }
}