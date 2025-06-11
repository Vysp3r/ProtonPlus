namespace ProtonPlus.Widgets {
    public class LibraryBox : Gtk.Widget {
        public delegate void load_steam_profile_func(Models.SteamProfile profile);

        Models.Launcher launcher { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        ShortcutButton shortcut_button { get; set; }
        MassEditButton mass_edit_button { get; set; }
        Adw.HeaderBar header_bar { get; set; }
        Gtk.Box action_box { get; set; }
        SelectButton select_button { get; set; }
        UnselectButton unselect_button { get; set; }
        SortByNameButton sort_by_name_button { get; set; }
        SortByToolButton sort_by_tool_button { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        Gtk.ListBox game_list_box { get; set; }
        Gtk.Label warning_label { get; set; }
        Gtk.Box content_box { get; set; }
        Adw.Spinner spinner { get; set; }
        Gtk.Overlay overlay { get; set; }
        Gtk.BinLayout bin_layout { get; set; }
        ListStore model { get; set; }
        Gtk.PropertyExpression expression { get; set; }

        construct {
            window_title = new Adw.WindowTitle("", "");

            header_bar = new Adw.HeaderBar();
            header_bar.set_title_widget(window_title);

            game_list_box = new Gtk.ListBox();
            game_list_box.set_selection_mode(Gtk.SelectionMode.MULTIPLE);
            game_list_box.add_css_class("boxed-list");
            game_list_box.row_activated.connect(game_list_box_row_activated);

            spinner = new Adw.Spinner();
            spinner.set_halign(Gtk.Align.CENTER);
            spinner.set_valign(Gtk.Align.CENTER);
            spinner.set_size_request(200, 200);

            overlay = new Gtk.Overlay();
            overlay.set_child(game_list_box);

            scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.set_vexpand(true);
            scrolled_window.set_child(overlay);
            scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);

            warning_label = new Gtk.Label(_("Close the Steam client beforehand so that the changes can be applied."));
            warning_label.add_css_class("warning");

            shortcut_button = new ShortcutButton();

            mass_edit_button = new MassEditButton(game_list_box);

            select_button = new SelectButton(game_list_box);

            unselect_button = new UnselectButton(game_list_box);

            sort_by_name_button = new SortByNameButton(game_list_box);

            sort_by_tool_button = new SortByToolButton(game_list_box);

            action_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            action_box.add_css_class("card");
            action_box.add_css_class("p-10");
            action_box.append(shortcut_button);
            action_box.append(mass_edit_button);
            action_box.append(select_button);
            action_box.append(unselect_button);
            action_box.append(sort_by_name_button);
            action_box.append(sort_by_tool_button);

            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            content_box.set_margin_top(7);
            content_box.set_margin_bottom(12);
            content_box.set_margin_start(12);
            content_box.set_margin_end(12);
            content_box.append(action_box);
            content_box.append(scrolled_window);
            content_box.append(warning_label);

            toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.set_content(content_box);
            toolbar_view.set_parent(this);

            bin_layout = new Gtk.BinLayout();
            set_layout_manager(bin_layout);
        }

        public void load(Models.Launcher launcher) {
            this.launcher = launcher;

            window_title.set_title("%s %s".printf(launcher.title, _("Library")));

            game_list_box.remove_all();

            if (launcher is Models.Launchers.Steam) {
                var steam_launcher = (Models.Launchers.Steam) launcher;

                shortcut_button.reset();
                shortcut_button.set_visible(true);

                warning_label.set_visible(true);

                if (steam_launcher.profiles.length() > 1 || 1 == 1) {
                    var dialog = new ProfileDialog(steam_launcher, load_steam_profile);
                    dialog.present(Application.window);
                } else {
                    load_steam_profile(steam_launcher.profiles.nth_data(0));
                }
            } else {
                load_games();
            }
        }

        void load_games() {
            overlay.add_overlay(spinner);

            launcher.load_game_library.begin((obj, res) => {
                var loaded = launcher.load_game_library.end(res);

                if (loaded) {
                    model = new ListStore(typeof (Models.SimpleRunner));
                    foreach (var ct in launcher.compatibility_tools)
                        model.append(ct);

                    expression = new Gtk.PropertyExpression(typeof (Models.SimpleRunner), null, "display_title");

                    mass_edit_button.load(model, expression);

                    foreach (var game in launcher.games) {
                        var game_row = new GameRow(game, model, expression);

                        game_list_box.append(game_row);
                    }

                    sort_by_name_button.clicked();

                    window_title.set_subtitle("%u installed games".printf(launcher.games.length()));
                }

                overlay.remove_overlay(spinner);
            });
        }

        void load_steam_profile(Models.SteamProfile profile) {
            var steam_launcher = (Models.Launchers.Steam) launcher;
            steam_launcher.profile = profile;

            shortcut_button.load(profile);

            load_games();
        }

        void game_list_box_row_activated(Gtk.ListBoxRow? row) {
            if (row == null || !(row is GameRow))
                return;

            var game_row = (GameRow) row;

            if (game_row.selected) {
                game_row.selected = false;
                game_list_box.unselect_row(game_row);
            } else {
                game_row.selected = true;
            }
        }
    }
}