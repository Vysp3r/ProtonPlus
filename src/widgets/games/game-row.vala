namespace ProtonPlus.Widgets {
    public class GameRow : Gtk.ListBoxRow {
        Gtk.GestureClick title_gesture;
        Gtk.GestureClick prefix_gesture;
        Gtk.CheckButton select_check_button;
        Gtk.Label title_label;
        Gtk.Label prefix_label;
        Gtk.Label tool_label;
        Gtk.Button tool_button;
        Gtk.Button run_custom_executable_button;
        ExtraButton extra_button;
        Gtk.Box other_box;
        Gtk.Box content_box;
        public Models.Game game { get; set; }

        public signal void mass_edit_requested (GameRow row);

        public bool selected { get; set; }

        public GameRow(Models.Game game) {
            this.game = game;

            select_check_button = new Gtk.CheckButton();
            select_check_button.set_size_request (30, 0);
            select_check_button.bind_property ("active", this, "selected", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);

            title_label = new Gtk.Label(game.name);
            title_label.set_tooltip_text (title_label.get_label ());
            title_label.set_halign (Gtk.Align.START);
            title_label.set_hexpand (true);
            title_label.set_ellipsize (Pango.EllipsizeMode.END);

            title_gesture = new Gtk.GestureClick();
            title_gesture.pressed.connect((gesture, n_press, x, y) => {
                if (n_press == 1)
                    open_install_directory_button_clicked();
            });

            prefix_label = new Gtk.Label(game.prefix.to_string ());
            prefix_label.set_xalign (0);
            prefix_label.set_tooltip_text (prefix_label.get_label ());
            prefix_label.set_max_width_chars (10);
            prefix_label.set_ellipsize (Pango.EllipsizeMode.END);
            prefix_label.set_size_request (110, 0);

            prefix_gesture = new Gtk.GestureClick();
            prefix_gesture.pressed.connect((gesture, n_press, x, y) => {
                if (n_press == 1)
                    open_prefix_directory_button_clicked();
            });

            tool_label = new Gtk.Label (null);
            tool_label.set_xalign (0.0f);
            tool_label.set_max_width_chars (30);
            tool_label.set_ellipsize (Pango.EllipsizeMode.END);
            tool_label.set_size_request (250, 0);
            refresh_tool_label ();

            extra_button = new ExtraButton(game);

            other_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            other_box.set_size_request (122, 0);
            other_box.append (extra_button);

            content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            content_box.set_hexpand (true);
            content_box.set_margin_start (10);
            content_box.set_margin_end (10);
            content_box.set_margin_top (10);
            content_box.set_margin_bottom (10);
            content_box.set_valign (Gtk.Align.CENTER);
            content_box.append (select_check_button);
            content_box.append (title_label);
            content_box.append (prefix_label);
            content_box.append (tool_label);
            content_box.append (other_box);

            if (game is Models.Games.Steam)
            load_steam ((Models.Games.Steam) game);

            set_child (content_box);
            set_selectable (false);
        }

        void add_hover_underline (Gtk.Label label) {
            var motion = new Gtk.EventControllerMotion();
            motion.enter.connect((x, y) => {
                var list = new Pango.AttrList ();
                list.insert (Pango.attr_underline_new (Pango.Underline.SINGLE));
                label.attributes = list;
            });
            motion.leave.connect(() => {
                label.attributes = null;
            });
            label.add_controller(motion);
        }

        public void refresh_tool_label () {
            string tool_name = _ ("Default");

            foreach (var tool in game.launcher.compatibility_tools) {
                if (tool.internal_title == game.compatibility_tool) {
                    tool_name = tool.display_title;
                    break;
                }
            }

            tool_label.set_label (tool_name);
        }

        void load_steam (Models.Games.Steam game) {
            tool_button = new Gtk.Button.from_icon_name("screwdriver-wrench-symbolic");
            tool_button.set_tooltip_text (_ ("Modify the game"));
            tool_button.add_css_class ("flat");
            tool_button.clicked.connect (() => mass_edit_requested (this));

            run_custom_executable_button = new Gtk.Button.from_icon_name("exe-file-format-symbolic");
            run_custom_executable_button.set_tooltip_text (_ ("Run custom executable"));
            run_custom_executable_button.add_css_class ("flat");
            run_custom_executable_button.clicked.connect (run_custom_executable_button_clicked);
            run_custom_executable_button.set_sensitive (FileUtils.test (game.prefixdir, GLib.FileTest.IS_DIR));

            if (FileUtils.test (game.installdir, GLib.FileTest.IS_DIR)) {
                title_label.set_tooltip_text (_("Browse game install directory"));
                title_label.add_controller(title_gesture);
                add_hover_underline (title_label);
            }

            if (FileUtils.test (game.prefixdir, GLib.FileTest.IS_DIR)) {
                prefix_label.set_tooltip_text (_("Browse prefix directory"));
                prefix_label.add_controller(prefix_gesture);
                add_hover_underline (prefix_label);
            }

            other_box.prepend (run_custom_executable_button);
            other_box.prepend (tool_button);
        }

        void open_install_directory_button_clicked () {
            Utils.System.open_uri ("file://%s".printf (game.installdir));
        }

        void open_prefix_directory_button_clicked () {
            Utils.System.open_uri ("file://%s".printf (game.prefixdir));
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
