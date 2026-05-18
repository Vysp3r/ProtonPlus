namespace ProtonPlus.Widgets.Tools {
    public class MigrateBox : Gtk.Box {
        Gee.ArrayList<Models.Game> games;
        string current_tool_name;
        Models.Launcher launcher;

        Adw.ComboRow combo_row;
        public Gtk.Button migrate_button { get; private set; }
        public Gtk.MenuButton games_button { get; private set; }
        Gee.ArrayList<string> possible_tools_internal;

        public signal void finished ();

        public MigrateBox () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            combo_row = new Adw.ComboRow () {
                title = _ ("New tool")
            };

            var group = new Adw.PreferencesGroup ();
            group.add (combo_row);

            var clamp = new Adw.Clamp () {
                maximum_size = 600,
                child = group
            };

            games_button = new Gtk.MenuButton () {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                css_classes = {"flat", "bold"}
            };

            var status_page = new Adw.StatusPage () {
                title = _ ("Migrate games"),
                description = _ ("Select a new tool for the selected games."),
                icon_name = "right-left-symbolic",
                vexpand = true,
                child = clamp,
            };

            migrate_button = new Gtk.Button.with_label (_ ("Migrate")) {
                valign = Gtk.Align.CENTER,
                visible = false,
            };
            migrate_button.add_css_class ("suggested-action");
            migrate_button.clicked.connect (on_migrate_clicked);

            append (status_page);
        }

        public void init (Gee.ArrayList<Models.Game> games, string current_tool_name, Models.Launcher launcher) {
            this.games = games;
            this.current_tool_name = current_tool_name;
            this.launcher = launcher;

            games_button.label = ngettext ("%d game selected", "%d games selected", games.size).printf (games.size);

            var games_list_box = new Gtk.ListBox ();
            games_list_box.set_selection_mode (Gtk.SelectionMode.NONE);
            games_list_box.add_css_class ("boxed-list");

            foreach (var game in games) {
                var label = new Gtk.Label (game.name);
                label.set_xalign (0);
                label.set_margin_start (10);
                label.set_margin_end (10);
                label.set_margin_top (5);
                label.set_margin_bottom (5);
                games_list_box.append (label);
            }

            var scrolled = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                max_content_height = 300,
                propagate_natural_height = true,
                child = games_list_box
            };

            var popover = new Gtk.Popover ();
            popover.set_child (scrolled);
            games_button.set_popover (popover);

            var model = new Gtk.StringList (null);
            possible_tools_internal = new Gee.ArrayList<string> ();

            var all_native = games.size > 0;
            foreach (var game in games) {
                if (!game.is_native) {
                    all_native = false;
                    break;
                }
            }

            foreach (var tool in launcher.compatibility_tools) {
                if (tool.internal_title != current_tool_name) {
                    if (tool.display_title.contains ("Steam Linux Runtime") && !all_native)
                    continue;

                    model.append (tool.display_title);
                    possible_tools_internal.add (tool.internal_title);
                }
            }

            if (launcher is Models.Launchers.Steam && current_tool_name != "Default") {
                model.append (_ ("Default"));
                possible_tools_internal.add ("Default");
            }

            combo_row.model = model;
            migrate_button.sensitive = possible_tools_internal.size > 0;
        }

        void on_migrate_clicked () {
            var selected_index = combo_row.selected;
            if (selected_index >= possible_tools_internal.size)
            return;

            var new_tool_internal = possible_tools_internal[(int)selected_index];

            migrate_button.sensitive = false;

            foreach (var game in games) {
                game.change_compatibility_tool (new_tool_internal);
            }

            finished ();
        }
    }
}
