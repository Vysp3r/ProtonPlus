namespace ProtonPlus.Widgets {
    public class ExtraButton : Gtk.Button {
        Models.Game game;
        Gtk.Button open_install_directory_button;
        Gtk.Button open_prefix_directory_button;
        Gtk.Button open_protontricks_button;
        Gtk.Button run_custom_executable_button;
        Gtk.Box content_box;
        Gtk.Popover popover;

        construct {
            open_install_directory_button = new Gtk.Button.with_label(_ ("Open install directory"));
            open_install_directory_button.clicked.connect (open_install_directory_button_clicked);

            open_prefix_directory_button = new Gtk.Button.with_label(_ ("Open prefix directory"));
            open_prefix_directory_button.clicked.connect (open_prefix_directory_button_clicked);

            open_protontricks_button = new Gtk.Button.with_label(_ ("Open in protontricks"));
            open_protontricks_button.clicked.connect (open_protontricks_button_clicked);

            run_custom_executable_button = new Gtk.Button.with_label(_ ("Run custom executable"));
            run_custom_executable_button.clicked.connect (run_custom_executable_button_clicked);

            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            content_box.append (open_install_directory_button);
            content_box.append (open_prefix_directory_button);

            popover = new Gtk.Popover();
            popover.set_autohide (true);
            popover.set_parent (this);
            popover.set_child (content_box);

            clicked.connect (extra_button_clicked);

            set_icon_name ("dots-symbolic");
            set_tooltip_text (_ ("Open menu"));
            add_css_class ("flat");
        }

        public ExtraButton(Models.Game game) {
            this.game = game;

            if (game is Models.Games.Steam) {
                if (Globals.PROTONTRICKS_EXEC != null)
                content_box.append (open_protontricks_button);

                var steam_game = game as Models.Games.Steam;
                open_install_directory_button.set_sensitive (!steam_game.is_non_steam);
                open_prefix_directory_button.set_sensitive (FileUtils.test (game.prefixdir, GLib.FileTest.IS_DIR));
                open_protontricks_button.set_sensitive (!steam_game.is_non_steam);

                content_box.append (run_custom_executable_button);
                run_custom_executable_button.set_sensitive (FileUtils.test (game.prefixdir, GLib.FileTest.IS_DIR));
            }
        }

        public override void dispose () {
            popover.unparent ();

            base.dispose ();
        }

        void extra_button_clicked () {
            popover.popup ();
        }

        void open_install_directory_button_clicked () {
            Utils.System.open_uri ("file://%s".printf (game.installdir));

            popover.popdown ();
        }

        void open_prefix_directory_button_clicked () {
            Utils.System.open_uri ("file://%s".printf (game.prefixdir));

            popover.popdown ();
        }

        void open_protontricks_button_clicked () {
            var steam_game = game as Models.Games.Steam;

            Utils.System.run_command.begin ("%s %u --gui".printf (Globals.PROTONTRICKS_EXEC, steam_game.appid));

            popover.popdown ();
        }

        void run_custom_executable_button_clicked () {
            var file_dialog = new Gtk.FileDialog ();
            file_dialog.set_title (_ ("Select executable"));

            var filters = new ListStore (typeof (Gtk.FileFilter));
            var filter = new Gtk.FileFilter ();
            filter.add_pattern ("*.exe");
            filter.add_pattern ("*.msi");
            filter.add_pattern ("*.msu");
            filter.name = _ ("Executables (*.exe, *.msi, *.msu)");
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

            popover.popdown ();
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