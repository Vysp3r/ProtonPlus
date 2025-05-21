namespace ProtonPlus.Widgets {
    public class LibraryDialog : Adw.Dialog {
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Adw.ButtonContent shortcut_button_content { get; set; }
        Gtk.Button shortcut_button { get; set; }
        Adw.HeaderBar header_bar { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        Adw.PreferencesGroup game_group { get; set; }

        construct {
            window_title = new Adw.WindowTitle("", "");

            shortcut_button_content = new Adw.ButtonContent();
            shortcut_button_content.set_icon_name("bookmark-plus-symbolic");
            shortcut_button_content.set_label(_("Create shortcut"));

            shortcut_button = new Gtk.Button();
            shortcut_button.set_tooltip_text(_("Create a shortcut of ProtonPlus in Steam"));
            shortcut_button.set_child(shortcut_button_content);

            header_bar = new Adw.HeaderBar();
            header_bar.pack_start(shortcut_button);
            header_bar.set_title_widget(window_title);

            game_group = new Adw.PreferencesGroup();

            scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.set_child(game_group);
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

            var games = get_installed_games();

            foreach (var game in games) {
                var compatiblity_label = new Gtk.Label("Unsupported");

                var anticheat_button = new Gtk.Button.from_icon_name("shield-symbolic");
                anticheat_button.set_tooltip_text(_("Open AreWeAntiCheatYet page"));
                anticheat_button.add_css_class("flat");

                var protondb_image = new Gtk.Image.from_resource("/com/vysp3r/ProtonPlus/proton.png");

                var protondb_button = new Gtk.Button();
                protondb_button.set_child(protondb_image);
                protondb_button.set_tooltip_text(_("Open ProtonDB page"));
                protondb_button.add_css_class("flat");

                var input_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
                input_box.set_valign(Gtk.Align.CENTER);
                input_box.append(compatiblity_label);
                input_box.append(anticheat_button);
                input_box.append(protondb_button);

                var row = new Adw.ActionRow();
                row.set_title(game.name);
                row.add_suffix(input_box);

                game_group.add(row);
            }

            window_title.set_subtitle("%u games".printf(games.length()));
        }

        public class Game : Object {
            public int appid { get; set; }
            public string name { get; set; }
            public string installdir { get; set; }
            public int library_folder_id { get; set; }
            public string library_folder_path { get; set; }

            public Game(int appid, string name, string installdir, int library_folder_id, string library_folder_path) {
                this.appid = appid;
                this.name = name;
                this.installdir = installdir;
                this.library_folder_id = library_folder_id;
                this.library_folder_path = library_folder_path;
            }
        }

        List<Game> get_installed_games() {
            var games = new List<Game> ();

            var libraryfolder_content = Utils.Filesystem.get_file_content("/home/vysp3r/.steam/steam/steamapps/libraryfolders.vdf");
            var current_libraryfolder_content = "";
            var current_libraryfolder_id = 0;
            var current_libraryfolder_path = "";
            var current_apps = "";
            var current_appid = "";
            var current_steamapps_path = "";
            var current_manifest_path = "";
            var current_manifest_content = "";
            var current_name = "";
            var current_installdir = "";
            var start_text = "";
            var end_text = "";
            var start_pos = 0;
            var end_pos = 0;
            var current_position = 0;
            
            while (true) {
                start_text = "%i\"\n\t{".printf(current_libraryfolder_id++);
                end_text = "}";
                start_pos = libraryfolder_content.index_of(start_text, 0) + start_text.length;

                if (start_pos - start_text.length == -1)
                    break;

                end_pos = libraryfolder_content.index_of(end_text, start_pos);
                current_libraryfolder_content = libraryfolder_content.substring(start_pos, end_pos - start_pos);
                current_position = end_pos;

                if (current_libraryfolder_content.contains("apps")) {
                    end_pos = libraryfolder_content.index_of(end_text, current_position + 1);
                    current_libraryfolder_content = libraryfolder_content.substring(start_pos, end_pos - start_pos);
                    // message("current_libraryfolder_id: %i, start: %i, end: %i, current_libraryfolder_content: %s", current_libraryfolder_id, start_pos, end_pos, current_libraryfolder_content);

                    start_text = "path\"\t\t\"";
                    end_text = "\"";
                    start_pos = current_libraryfolder_content.index_of(start_text, 0) + start_text.length;
                    end_pos = current_libraryfolder_content.index_of(end_text, start_pos);
                    current_libraryfolder_path = current_libraryfolder_content.substring(start_pos, end_pos - start_pos);
                    current_position = end_pos;
                    // message("start: %i, end: %i, current_libraryfolder_path: %s", start_pos, end_pos, current_libraryfolder_path);

                    start_text = "apps\"\n\t\t{\n";
                    end_text = "}";
                    start_pos = current_libraryfolder_content.index_of(start_text, current_position) + start_text.length;
                    end_pos = current_libraryfolder_content.index_of(end_text, start_pos + start_text.length);
                    current_apps = current_libraryfolder_content.substring(start_pos, end_pos - start_pos);
                    current_position = 0;
                    // message("start: %i, end: %i, apps: %s", start_pos, end_pos, current_apps);

                    while (true) {
                        start_text = "\t\t\t\"";
                        end_text = "\"";
                        start_pos = current_apps.index_of(start_text, current_position) + start_text.length;

                        if (start_pos - start_text.length == -1)
                            break;

                        end_pos = current_apps.index_of(end_text, start_pos + start_text.length);
                        current_appid = current_apps.substring(start_pos, end_pos - start_pos);
                        current_position = end_pos;
                        //message("start: %i, end: %i, id: %s", start_pos, end_pos, current_appid);

                        current_steamapps_path = "%s/steamapps".printf(current_libraryfolder_path);
                        current_manifest_path = "%s/appmanifest_%s.acf".printf(current_steamapps_path, current_appid);
                        current_manifest_content = Utils.Filesystem.get_file_content(current_manifest_path);
                        //message("current_manifest_path: %s", current_manifest_path);

                        start_text = "name\"\t\t\"";
                        end_text = "\"";
                        start_pos = current_manifest_content.index_of(start_text, 0) + start_text.length;
                        end_pos = current_manifest_content.index_of(end_text, start_pos);
                        current_name = current_manifest_content.substring(start_pos, end_pos - start_pos);
                        message("start: %i, end: %i, current_name: %s", start_pos, end_pos, current_name);

                        start_text = "installdir\"\t\t\"";
                        end_text = "\"";
                        start_pos = current_manifest_content.index_of(start_text, 0) + start_text.length;
                        end_pos = current_manifest_content.index_of(end_text, start_pos);
                        current_installdir = current_manifest_content.substring(start_pos, end_pos - start_pos);
                        //message("start: %i, end: %i, current_installdir: %s", start_pos, end_pos, current_installdir);

                        if(!FileUtils.test("%s/common/%s".printf(current_steamapps_path, current_installdir), FileTest.IS_DIR))
                            continue;

                        games.append(new Game(int.parse(current_appid), current_name, current_installdir, current_libraryfolder_id, current_libraryfolder_path));
                    }
                } else {
                    continue;
                }
            }

            return games;
        }
    }
}