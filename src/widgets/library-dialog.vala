namespace ProtonPlus.Widgets {
    public class LibraryDialog : Adw.Dialog {
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.ButtonContent shortcut_button_content { get; set; }
        Gtk.Button shortcut_button { get; set; }
        Adw.ButtonContent mass_edit_button_content { get; set; }
        Gtk.Button mass_edit_button { get; set; }
        Adw.HeaderBar header_bar { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        Gtk.ListBox game_list_box { get; set; }

        construct {
            window_title = new Adw.WindowTitle("", "");

            shortcut_button_content = new Adw.ButtonContent();
            shortcut_button_content.set_icon_name("bookmark-plus-symbolic");
            shortcut_button_content.set_label(_("Create shortcut"));

            shortcut_button = new Gtk.Button();
            shortcut_button.set_tooltip_text(_("Create a shortcut of ProtonPlus in Steam"));
            shortcut_button.set_child(shortcut_button_content);

            mass_edit_button_content = new Adw.ButtonContent();
            mass_edit_button_content.set_icon_name("edit-symbolic");
            mass_edit_button_content.set_label(_("Mass edit"));

            mass_edit_button = new Gtk.Button();
            mass_edit_button.set_tooltip_text(_("Mass edit the compatibility tool of the selected games"));
            mass_edit_button.set_child(mass_edit_button_content);

            header_bar = new Adw.HeaderBar();
            header_bar.pack_start(shortcut_button);
            header_bar.pack_end(mass_edit_button);
            header_bar.set_title_widget(window_title);

            game_list_box = new Gtk.ListBox();
            game_list_box.set_selection_mode(Gtk.SelectionMode.MULTIPLE);
            game_list_box.add_css_class("boxed-list");

            scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.set_child(game_list_box);
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

        public LibraryDialog(string launcher_title) {
            window_title.set_title("%s %s".printf(_("Game library of"), launcher_title));

            Models.Game.get_installed_games.begin((obj, res) => {
                var games = Models.Game.get_installed_games.end(res);

                foreach (var game in games) {
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
                    box.set_margin_start (10);
                    box.set_margin_end (10);
                    box.set_margin_top (10);
                    box.set_margin_bottom (10);
                    box.set_valign(Gtk.Align.CENTER);
                    box.append(title_label);
                    box.append(anticheat_button);
                    box.append(protondb_button);
                    box.set_tooltip_markup(game.compat_tool);

                    game_list_box.append(box);
                }

                window_title.set_subtitle("%u games".printf(games.length()));
            });
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