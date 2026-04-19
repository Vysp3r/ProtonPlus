namespace ProtonPlus.Widgets {
    public class MassEditView : Gtk.Box {
        public signal void back_requested ();

        Gtk.Button back_button;
        Gtk.Button clear_button;
        Gtk.Switch advanced_switch { get; set; }
        Gtk.Box advanced_box;
        Gtk.Button apply_button;
        Adw.HeaderBar header_bar { get; set; }
        Adw.Clamp content_clamp { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        CompatibilityToolRow compatibility_tool_row { get; set; }
        Adw.PreferencesGroup compatibility_tool_group { get; set; }
        Adw.PreferencesGroup launch_options_group { get; set; }
        LaunchOptionsEditor launch_options_editor { get; set; }
        Gtk.Box content_box { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        public GameRow[] rows;

        public string get_selection_text () {
            return rows.length == 1 ? _ ("1 game selected") : _ ("%u games selected").printf (rows.length);
        }

        public MassEditView (Gtk.Button back_button, Gtk.Button clear_button, Gtk.Button apply_button, Gtk.Box advanced_box, Gtk.Switch advanced_switch) {
            set_orientation (Gtk.Orientation.VERTICAL);

            this.back_button = back_button;
            this.clear_button = clear_button;
            this.apply_button = apply_button;
            this.advanced_box = advanced_box;
            this.advanced_switch = advanced_switch;

            this.back_button.clicked.connect (() => back_requested ());
            this.clear_button.clicked.connect (clear_button_clicked);
            this.apply_button.clicked.connect (apply_button_clicked);

            compatibility_tool_group = new Adw.PreferencesGroup();
            compatibility_tool_group.set_title (_ ("Compatibility tool"));
            compatibility_tool_group.set_margin_bottom (15);

            launch_options_editor = new LaunchOptionsEditor ();
            advanced_switch.notify["active"].connect (() => launch_options_editor.set_advanced_visible (advanced_switch.get_active ()));
            launch_options_editor.content_changed.connect (refresh);
            
            launch_options_group = new Adw.PreferencesGroup();
            launch_options_group.set_title (_ ("Launch options"));

            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            content_box.append (compatibility_tool_group);
            content_box.append (launch_options_group);
            content_box.append (launch_options_editor);

            content_clamp = new Adw.Clamp ();
            content_clamp.set_maximum_size (975);
            content_clamp.set_child (content_box);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_hexpand (true);
            scrolled_window.set_vexpand (true);
            scrolled_window.set_child (content_clamp);

            append (scrolled_window);
        }

        public void load (GameRow[] rows, ListStore model, Gtk.PropertyExpression expression) {
            this.rows = rows;

            if (compatibility_tool_row != null)
            compatibility_tool_group.remove (compatibility_tool_row);

            compatibility_tool_row = new CompatibilityToolRow (model, expression);
            compatibility_tool_group.add (compatibility_tool_row);

            advanced_switch.set_active (false);
            launch_options_editor.set_text ("");

            var has_steam_launch_options = rows[0].game.launcher is Models.Launchers.Steam;
            launch_options_group.set_visible (has_steam_launch_options);
            launch_options_editor.set_visible (has_steam_launch_options);

            refresh ();
        }

        void refresh () {
            clear_button.set_sensitive (launch_options_editor.has_clearable_state ());
            apply_button.set_sensitive (launch_options_editor.has_clearable_state ());
        }

        void clear_button_clicked () {
            launch_options_editor.clear ();
            refresh ();
        }

        void apply_button_clicked () {
            var item = (Models.SimpleRunner) compatibility_tool_row.get_selected_item ();
            var invalids = new List<string> ();

            foreach (var row in rows) {
                {
                    var valids = new List<GameRow> ();

                    var success = row.game.change_compatibility_tool (item.internal_title);
                    if (!success && invalids.find (row.game.name) == null)
                    invalids.append (row.game.name);
                    else
                    valids.append (row);

                    if (valids.length () > 0) {
                        foreach (var valid_row in valids) {
                            valid_row.refresh_tool_label ();
                        }
                    }
                }

                if (row.game.launcher is Models.Launchers.Steam) {
                    var valids = new List<GameRow> ();

                    var steam_game = (Models.Games.Steam) row.game;
                    var steam_launcher = (Models.Launchers.Steam) steam_game.launcher;

                    var success = steam_game.change_launch_options (launch_options_editor.get_text (), steam_launcher.profile.localconfig_path);
                    if (!success && invalids.find (row.game.name) == null)
                    invalids.append (row.game.name);
                    else
                    valids.append (row);
                }
            }

            if (invalids.length () > 0) {
                var names = "";

                for (var i = 0; i < invalids.length (); i++) {
                    names += "- %s".printf (invalids.nth_data (i));

                    if (i != invalids.length () - 1)
                    names += "\n";
                }

                var dialog = new ErrorDialog (_ ("Couldn't change the compatibility tool/launch options of the selected games"), "%s\n\n%s\n\n%s".printf (_ ("The following games had an issue:"), names, _ ("Please report this issue on GitHub.")));
                dialog.present (Application.window);
            }

            back_requested ();
        }
    }
}
