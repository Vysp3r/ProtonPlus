namespace ProtonPlus.Widgets.Tools {
    public class ReleaseGamesDialog : Adw.Dialog {
        public signal void migrate_requested (Gee.ArrayList<Models.Game> games);

        Gtk.ListBox list_box;
        Gtk.CheckButton check_button;
        Gtk.Button migrate_button;
        bool updating_select_all = false;

        public ReleaseGamesDialog (Services.InstallJob job) {
            Object (title: _("Games using %s").printf (job.title));

            var window_title = new Adw.WindowTitle (
                _("Games Using This Tool"), ReleaseRow.release_display_title (job)
            );
            var header_bar = new Adw.HeaderBar ();
            header_bar.set_title_widget (window_title);

            var migrate_button_content = new Adw.ButtonContent () {
                label = _("Migrate"),
                icon_name = "right-left-symbolic"
            };
            migrate_button = new Gtk.Button () {
                valign = Gtk.Align.CENTER,
                visible = false,
                child = migrate_button_content
            };
            migrate_button.set_tooltip_text (
                _("Migrate selected games to another tool")
            );
            migrate_button.clicked.connect (() => {
                var games = get_selected_games ();
                if (games.size > 0) {
                    close ();
                    migrate_requested (games);
                }
            });
            header_bar.pack_end (migrate_button);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");

            check_button = new Gtk.CheckButton ();
            check_button.set_tooltip_text (_("Select all games"));
            check_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Select all games"), -1
            );
            check_button.toggled.connect (() => {
                if (updating_select_all)
                    return;

                var is_active = check_button.get_active ();
                updating_select_all = true;
                var child = list_box.get_first_child ();
                while (child != null) {
                    if (child is GameRow)
                        ((GameRow) child).selected = is_active;
                    child = child.get_next_sibling ();
                }
                updating_select_all = false;
                update_selection_state ();
            });

            var select_all_row = new Adw.ActionRow () {
                title = _("Select all games"),
                activatable_widget = check_button
            };
            select_all_row.add_prefix (check_button);
            list_box.append (select_all_row);

            var steam_launcher = job.tool.group.launcher as Models.Launchers.Steam;
            var has_games = false;
            if (steam_launcher != null) {
                var tool_name = job.get_usage_identifier ();
                foreach (var game in ((!) steam_launcher).get_compatibility_tool_usage_games (tool_name)) {
                    var row = new GameRow (game);
                    row.notify["selected"].connect (update_selection_state);
                    list_box.append (row);
                    has_games = true;
                }
            }

            Gtk.Widget content;
            if (has_games) {
                var games_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                    margin_start = 12,
                    margin_end = 12,
                    margin_top = 24,
                    margin_bottom = 24
                };
                games_content.append (list_box);

                var games_clamp = new Adw.Clamp () {
                    maximum_size = 720,
                    tightening_threshold = 600,
                    child = games_content
                };
                content = new Gtk.ScrolledWindow () {
                    vexpand = true,
                    hscrollbar_policy = Gtk.PolicyType.NEVER,
                    vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                    child = games_clamp
                };
            } else {
                content = new Adw.StatusPage () {
                    title = _("No Games Use This Tool"),
                    icon_name = "gamepad-symbolic",
                    vexpand = true
                };
            }

            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (content);

            set_content_width (720);
            set_content_height (600);
            set_can_close (true);
            set_child (toolbar_view);
            update_selection_state ();
        }

        void update_selection_state () {
            if (updating_select_all)
                return;

            var selected = 0;
            var total = 0;
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow) {
                    total++;
                    if (((GameRow) child).selected)
                        selected++;
                }
                child = child.get_next_sibling ();
            }

            updating_select_all = true;
            check_button.set_inconsistent (selected > 0 && selected < total);
            check_button.set_active (total > 0 && selected == total);
            check_button.set_sensitive (total > 0);
            updating_select_all = false;
            migrate_button.set_visible (selected > 0);
        }

        Gee.ArrayList<Models.Game> get_selected_games () {
            var selected_games = new Gee.ArrayList<Models.Game> ();
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow && ((GameRow) child).selected)
                    selected_games.add (((GameRow) child).game);
                child = child.get_next_sibling ();
            }
            return selected_games;
        }
    }
}
