namespace ProtonPlus.Widgets {
    public class LibraryDialog : Adw.Dialog {
        Models.Launchers.Steam steam_launcher { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.ButtonContent shortcut_button_content { get; set; }
        Gtk.Button shortcut_button { get; set; }
        Adw.ButtonContent mass_edit_button_content { get; set; }
        Gtk.Button mass_edit_button { get; set; }
        Adw.HeaderBar header_bar { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        Gtk.ListBox game_list_box { get; set; }
        Gtk.Spinner spinner { get; set; }
        Gtk.Overlay overlay { get; set; }
        ListStore compat_tools_liststore { get; set; }
        Gtk.PropertyExpression compat_tools_expression { get; set; }

        construct {
            window_title = new Adw.WindowTitle("", "");

            shortcut_button_content = new Adw.ButtonContent();
            shortcut_button_content.set_icon_name("bookmark-plus-symbolic");

            shortcut_button = new Gtk.Button();
            shortcut_button.set_child(shortcut_button_content);
            shortcut_button.clicked.connect(shortcut_button_clicked);

            mass_edit_button_content = new Adw.ButtonContent();
            mass_edit_button_content.set_icon_name("edit-symbolic");
            mass_edit_button_content.set_label(_("Mass edit"));

            mass_edit_button = new Gtk.Button();
            mass_edit_button.set_tooltip_text(_("Mass edit the compatibility tool of the selected games"));
            mass_edit_button.set_child(mass_edit_button_content);
            mass_edit_button.clicked.connect(mass_edit_button_clicked);

            header_bar = new Adw.HeaderBar();
            header_bar.pack_start(shortcut_button);
            header_bar.pack_end(mass_edit_button);
            header_bar.set_title_widget(window_title);

            game_list_box = new Gtk.ListBox();
            game_list_box.set_selection_mode(Gtk.SelectionMode.MULTIPLE);
            game_list_box.add_css_class("boxed-list");

            spinner = new Gtk.Spinner();

            overlay = new Gtk.Overlay();
            overlay.set_child(game_list_box);

            scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.set_child(overlay);
            scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_size_request(675, 375);
            scrolled_window.set_margin_top(7);
            scrolled_window.set_margin_bottom(12);
            scrolled_window.set_margin_start(12);
            scrolled_window.set_margin_end(12);

            toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.set_content(scrolled_window);

            set_child(toolbar_view);
        }

        public LibraryDialog(Models.Launchers.Steam steam_launcher) {
            this.steam_launcher = steam_launcher;

            shortcut_button_refresh();

            window_title.set_title("%s %s".printf(_("Game library of"), steam_launcher.title));

            load();
        }

        void load() {
            overlay.add_overlay(spinner);

            spinner.start();

            game_list_box.remove_all();

            steam_launcher.load_library_data.begin((obj, res) => {
                var loaded = steam_launcher.load_library_data.end(res);

                if (!loaded) {
                    overlay_clear();
                    return;
                }

                compat_tools_liststore = new ListStore(typeof (Models.Launchers.Steam.RunnerDropDownItem));
                foreach (var ct in steam_launcher.compat_tools)
                    compat_tools_liststore.append(ct);

                compat_tools_expression = new Gtk.PropertyExpression(typeof (Models.Launchers.Steam.RunnerDropDownItem), null, "display_title");

                foreach (var game in steam_launcher.games) {
                    var game_row = new GameRow(game, compat_tools_liststore, compat_tools_expression);

                    game_list_box.append(game_row);
                }

                window_title.set_subtitle("%u games".printf(steam_launcher.games.length()));

                overlay_clear();
            });
        }

        void overlay_clear() {
            spinner.stop();
            overlay.remove_overlay(spinner);
        }

        void shortcut_button_refresh() {
            var shortcut_installed = steam_launcher.check_shortcuts_files();
            shortcut_button_content.set_label(!shortcut_installed ? _("Create shortcut") : _("Remove shortcut"));
            shortcut_button.set_tooltip_text(!shortcut_installed ? _("Create a shortcut of ProtonPlus in Steam") : _("Remove the shortcut of ProtonPlus in Steam"));
        }

        void shortcut_button_clicked() {
            var installed = steam_launcher.check_shortcuts_files();

            foreach (var file in steam_launcher.shortcuts_files) {
                var status = file.get_installed_status();

                if (installed) {
                    if (status) {
                        message("remove");
                        var success = steam_launcher.uninstall_shortcut(file);
                        if (!success) {
                            var dialog = new Adw.AlertDialog(_("An error occured"), "%s\n%s".printf(_("When trying to remove the shortcut in Steam an error occured."), _("Please report this issue on GitHub.")));
                            dialog.add_response("ok", "OK");
                            dialog.present(Application.window);
                        }
                    } else {
                        message("remove but not installed");
                    }
                } else {
                    if (!status) {
                        message("create");
                        var success = steam_launcher.install_shortcut(file);
                        if (!success) {
                            var dialog = new Adw.AlertDialog(_("An error occured"), "%s\n%s".printf(_("When trying to create the shortcut in Steam an error occured."), _("Please report this issue on GitHub.")));
                            dialog.add_response("ok", "OK");
                            dialog.present(Application.window);
                        }
                    } else {
                        message("create but already installed");
                    }
                }
            }

            shortcut_button_refresh();
        }

        void mass_edit_button_clicked() {
            var rows = game_list_box.get_selected_rows();

            if (rows.length() > 0) {
                var game_rows = new GameRow[rows.length()];
                for (var i = 0; i < rows.length(); i++) {
                    var game_row = (GameRow) rows.nth_data(i);
                    game_rows[i] = game_row;
                }

                var mass_edit_dialog = new MassEditDialog(game_rows, compat_tools_liststore, compat_tools_expression);
                mass_edit_dialog.present(Application.window);
            } else {
                var dialog = new Adw.AlertDialog(null, _("Please make sure to select at least one game before using the mass edit feature."));
                dialog.add_response("ok", "OK");
                dialog.present(Application.window);
            }
        }
    }
}