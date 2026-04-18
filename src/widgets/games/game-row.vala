namespace ProtonPlus.Widgets {
    public class GameRow : Gtk.ListBoxRow {
        public signal void launch_options_requested (GameRow row);

        Gtk.Label title_label;
        Gtk.Label prefix_label;
        public CompatibilityToolDropDown compatibility_tool_dropdown;
        Gtk.Button launch_options_button;
        Gtk.Button run_custom_executable_button;
        ExtraButton extra_button;
        Gtk.Box content_box;
        public Models.Game game { get; set; }

        public bool selected { get; set; }

        public GameRow(Models.Game game, ListStore model, Gtk.PropertyExpression expression) {
            this.game = game;

            title_label = new Gtk.Label(game.name);
            title_label.set_tooltip_text (title_label.get_label ());
            title_label.set_halign (Gtk.Align.START);
            title_label.set_hexpand (true);
            title_label.set_ellipsize (Pango.EllipsizeMode.END);

            prefix_label = new Gtk.Label(game.prefix.to_string ());
            prefix_label.set_tooltip_text (prefix_label.get_label ());
            prefix_label.set_max_width_chars (10);
            prefix_label.set_ellipsize (Pango.EllipsizeMode.END);
            prefix_label.set_selectable (true);
            prefix_label.set_size_request (110, 0);

            compatibility_tool_dropdown = new CompatibilityToolDropDown (game, model, expression);

            extra_button = new ExtraButton(game);

            content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            content_box.set_margin_start (10);
            content_box.set_margin_end (10);
            content_box.set_margin_top (10);
            content_box.set_margin_bottom (10);
            content_box.set_valign (Gtk.Align.CENTER);
            content_box.append (title_label);
            content_box.append (prefix_label);
            content_box.append (compatibility_tool_dropdown);

            if (game is Models.Games.Steam)
            load_steam ((Models.Games.Steam) game);

            content_box.append (extra_button);

            set_child (content_box);
        }

        void load_steam (Models.Games.Steam game) {
            launch_options_button = new Gtk.Button.from_icon_name("square-poll-horizontal-symbolic");
            launch_options_button.set_tooltip_text (_ ("Modify the game launch options"));
            launch_options_button.add_css_class ("flat");
            launch_options_button.clicked.connect (launch_options_button_clicked);

            run_custom_executable_button = new Gtk.Button.from_icon_name("gears-symbolic");
            run_custom_executable_button.set_tooltip_text (_ ("Run custom executable"));
            run_custom_executable_button.add_css_class ("flat");
            run_custom_executable_button.clicked.connect (run_custom_executable_button_clicked);
            run_custom_executable_button.set_sensitive (FileUtils.test (game.prefixdir, GLib.FileTest.IS_DIR));

            content_box.append (launch_options_button);
            content_box.append (run_custom_executable_button);
        }

        void launch_options_button_clicked () {
            if (!(game is Models.Games.Steam))
            return;

            launch_options_requested (this);
        }

        void run_custom_executable_button_clicked () {
            var file_dialog = new Gtk.FileDialog ();
            file_dialog.set_title (_ ("Select executable"));

            var filters = new ListStore (typeof (Gtk.FileFilter));
            var filter = new Gtk.FileFilter ();
            filter.add_pattern ("*.exe");
            filter.add_pattern ("*.msi");
            filter.add_pattern ("*.msu");
            filter.add_pattern ("*.bat");
            filter.name = _ ("Executables (*.exe, *.msi, *.msu, *.bat)");
            filters.append (filter);

            file_dialog.set_filters (filters);

            file_dialog.open.begin (Application.window, null, (obj, res) => {
                try {
                    var file = file_dialog.open.end (res);
                    if (file != null) {
                        run_custom_executable (file.get_path ());
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            });
        }

        void run_custom_executable (string exe_path) {
            Models.SimpleRunner selected_runner = null;

            foreach (var runner in game.launcher.compatibility_tools) {
                if (runner.internal_title == game.compatibility_tool) {
                    selected_runner = runner;
                    break;
                }
            }

            if (selected_runner == null && game.launcher is Models.Launchers.Steam) {
                var steam = game.launcher as Models.Launchers.Steam;
                foreach (var runner in steam.compatibility_tools) {
                    if (runner.internal_title == "proton_experimental" || runner.internal_title.contains ("proton")) {
                        selected_runner = runner;
                        break;
                    }
                }
            }

            if (selected_runner == null || selected_runner.path == null) {
                var dialog = new ErrorDialog (_ ("Couldn't find the compatibility tool for %s").printf (game.name), _ ("Please make sure it's installed."));
                dialog.present (Application.window);
                return;
            }

            var proton_path = "%s/proton".printf (selected_runner.path);
            var steam_compat_data_path = game.prefixdir;
            var steam_compat_client_install_path = game.launcher.directory;

            var inner_command = "STEAM_COMPAT_DATA_PATH=%s STEAM_COMPAT_CLIENT_INSTALL_PATH=%s %s run %s".printf (
                Shell.quote (steam_compat_data_path),
                Shell.quote (steam_compat_client_install_path),
                Shell.quote (proton_path),
                Shell.quote (exe_path)
            );

            Utils.System.run_command.begin ("sh -c " + Shell.quote (inner_command));
        }
    }
}
