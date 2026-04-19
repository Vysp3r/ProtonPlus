namespace ProtonPlus.Widgets {
    public class ExtraButton : Gtk.Button {
        Models.Game game;
        Gtk.Button open_install_directory_button;
        Gtk.Button open_prefix_directory_button;
        Gtk.Button open_protontricks_button;
        Gtk.Button anticheat_button;
        Gtk.Button protondb_button;
        Gtk.Box content_box;
        Gtk.Popover popover;

        construct {
            open_install_directory_button = new Gtk.Button.with_label(_ ("Open install directory"));
            open_install_directory_button.clicked.connect (open_install_directory_button_clicked);

            open_prefix_directory_button = new Gtk.Button.with_label(_ ("Open prefix directory"));
            open_prefix_directory_button.clicked.connect (open_prefix_directory_button_clicked);

            open_protontricks_button = new Gtk.Button.with_label(_ ("Open in protontricks"));
            open_protontricks_button.clicked.connect (open_protontricks_button_clicked);

            protondb_button = new Gtk.Button.with_label(_ ("Open ProtonDB page"));
            protondb_button.clicked.connect (protondb_button_clicked);

            anticheat_button = new Gtk.Button.with_label(_ ("Open AreWeAntiCheatYet page"));
            anticheat_button.clicked.connect (anticheat_button_clicked);

            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            content_box.append (open_install_directory_button);
            content_box.append (open_prefix_directory_button);

            popover = new Gtk.Popover();
            popover.set_autohide (true);
            popover.set_parent (this);
            popover.set_child (content_box);

            clicked.connect (extra_button_clicked);

            set_icon_name ("view-more-symbolic");
            set_tooltip_text (_ ("Extra"));
            add_css_class ("flat");
        }

        public ExtraButton(Models.Game game) {
            this.game = game;

            if (game is Models.Games.Steam) {
                if (Globals.PROTONTRICKS_EXEC != null)
                content_box.append (open_protontricks_button);

                var steam_game = game as Models.Games.Steam;
                open_install_directory_button.set_visible (!steam_game.is_non_steam);
                open_prefix_directory_button.set_visible (FileUtils.test (game.prefixdir, GLib.FileTest.IS_DIR));
                open_protontricks_button.set_visible (!steam_game.is_non_steam);

                content_box.append (protondb_button);
                content_box.append (anticheat_button);

                anticheat_button.set_tooltip_text (steam_game.awacy_status);
                switch (steam_game.awacy_status) {
                    case "Supported":
                        anticheat_button.add_css_class ("green");
                        break;
                    case "Running":
                        anticheat_button.add_css_class ("blue");
                        break;
                    case "Planned":
                        anticheat_button.add_css_class ("purple");
                        break;
                    case "Broken":
                        anticheat_button.add_css_class ("orange");
                        break;
                    case "Denied":
                        anticheat_button.add_css_class ("red");
                        break;
                    default:
                        anticheat_button.set_tooltip_text (_ ("Unknown"));
                        anticheat_button.set_visible (false);
                        break;
                }

                protondb_button.set_visible (!steam_game.is_non_steam);
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

        void anticheat_button_clicked () {
            var steam_game = game as Models.Games.Steam;

            if (steam_game.awacy_name != null)
            Utils.System.open_uri ("https://areweanticheatyet.com/game/%s".printf (steam_game.awacy_name));

            popover.popdown ();
        }

        void protondb_button_clicked () {
            var steam_game = game as Models.Games.Steam;

            Utils.System.open_uri ("https://www.protondb.com/app/%u".printf (steam_game.appid));

            popover.popdown ();
        }
    }
}