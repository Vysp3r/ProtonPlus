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
            overlay.add_overlay(spinner);

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
            spinner.start();

            this.steam_launcher = steam_launcher;

            shortcut_button_refresh();

            window_title.set_title("%s %s".printf(_("Game library of"), steam_launcher.title));

            steam_launcher.load_library_data.begin((obj, res) => {
                var loaded = steam_launcher.load_library_data.end(res);

                if (!loaded) {
                    overlay_clear();
                    return;
                }

                var compat_tools_liststore = new ListStore(typeof (Models.Launchers.Steam.RunnerDropDownItem));
                foreach (var ct in steam_launcher.compat_tools)
                    compat_tools_liststore.append(ct);

                var compat_tools_expression = new Gtk.PropertyExpression(typeof (Models.Launchers.Steam.RunnerDropDownItem), null, "display_title");

                foreach (var game in steam_launcher.games) {
                    var compat_tool_dropdown = new Gtk.DropDown(compat_tools_liststore, compat_tools_expression);

                    for (var i = 0; i < steam_launcher.compat_tools.length(); i++) {
                        if (steam_launcher.compat_tools.nth_data(i).title == game.compat_tool) {
                            compat_tool_dropdown.set_selected(i);
                            break;
                        }
                    }

                    var anticheat_button = new Gtk.Button.from_icon_name("shield-symbolic");
                    anticheat_button.set_tooltip_text(_("Open AreWeAntiCheatYet page"));
                    anticheat_button.add_css_class("flat");
                    anticheat_button.clicked.connect(() => anticheat_button_clicked(game.awacy_name));

                    switch (game.awacy_status) {
                        case "Supported":
                            anticheat_button.add_css_class("green");
                            break;
                        case "Running":
                            anticheat_button.add_css_class("blue");
                            break;
                        case "Planned":
                            anticheat_button.add_css_class("purple");
                            break;
                        case "Broken":
                            anticheat_button.add_css_class("orange");
                            break;
                        case "Denied":
                            anticheat_button.add_css_class("red");
                            break;
                        default:
                            anticheat_button.set_visible(false);
                            break;
                    }

                    var protondb_image = new Gtk.Image.from_resource("/com/vysp3r/ProtonPlus/proton.png");

                    var protondb_button = new Gtk.Button();
                    protondb_button.set_child(protondb_image);
                    protondb_button.set_tooltip_text(_("Open ProtonDB page"));
                    protondb_button.add_css_class("flat");
                    protondb_button.clicked.connect(() => protondb_button_clicked(game.appid));

                    var title_label = new Gtk.Label(game.name);
                    title_label.set_halign(Gtk.Align.START);
                    title_label.set_hexpand(true);

                    var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
                    box.set_margin_start(10);
                    box.set_margin_end(10);
                    box.set_margin_top(10);
                    box.set_margin_bottom(10);
                    box.set_valign(Gtk.Align.CENTER);
                    box.append(title_label);
                    box.append(compat_tool_dropdown);
                    box.append(anticheat_button);
                    box.append(protondb_button);

                    game_list_box.append(box);
                }

                window_title.set_subtitle("%u games".printf(steam_launcher.games.length()));

                overlay_clear();
            });
        }

        void shortcut_button_refresh() {
            var shortcut_installed = steam_launcher.check_shortcut();
            shortcut_button_content.set_label(!shortcut_installed ? _("Create shortcut") : _("Remove shortcut"));
            shortcut_button.set_tooltip_text(!shortcut_installed ? _("Create a shortcut of ProtonPlus in Steam") : _("Remove the shortcut of ProtonPlus in Steam"));
        }

        void overlay_clear() {
            spinner.stop();
            overlay.remove_overlay(spinner);
        }

        void shortcut_button_clicked() {
            // TODO Handle if the install/uninstall function is not ran successfully (show error message)
            if (steam_launcher.check_shortcut()) {
                // steam_launcher.install_shortcut();
            } else {
                // steam_launcher.uninstall_shortcut();
            }

            shortcut_button_refresh();
        }

        void mass_edit_button_clicked() {
        }

        void anticheat_button_clicked(string? awacy_name) {
            if (awacy_name != null)
                Utils.System.open_url("https://areweanticheatyet.com/game/%s".printf(awacy_name));
        }

        void protondb_button_clicked(int appid) {
            Utils.System.open_url("https://www.protondb.com/app/%i".printf(appid));
        }
    }
}