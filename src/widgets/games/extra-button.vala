namespace ProtonPlus.Widgets {
    public class ExtraButton : Gtk.Button {
        Models.Game game;
        Gtk.Button open_protontricks_button;
        Gtk.Button anticheat_button;
        Gtk.Button protondb_button;
        Gtk.Box content_box;
        Gtk.Popover popover;

        construct {
            open_protontricks_button = new Gtk.Button.with_label(_ ("Open in protontricks"));
            open_protontricks_button.clicked.connect (open_protontricks_button_clicked);

            protondb_button = new Gtk.Button.with_label("ProtonDB");
            protondb_button.set_tooltip_text (_ ("Open ProtonDB page"));
            protondb_button.clicked.connect (protondb_button_clicked);

            anticheat_button = new Gtk.Button.with_label("AreWeAntiCheatYet");
            anticheat_button.clicked.connect (anticheat_button_clicked);

            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);

            popover = new Gtk.Popover();
            popover.set_autohide (true);
            popover.set_parent (this);
            popover.set_child (content_box);

            clicked.connect (extra_button_clicked);

            set_icon_name ("dots-symbolic");
            set_tooltip_text (_ ("Extra"));
            add_css_class ("flat");
        }

        public ExtraButton(Models.Game game) {
            this.game = game;

            if (game is Models.Games.Steam) {
                if (Globals.PROTONTRICKS_EXEC != null)
                content_box.append (open_protontricks_button);

                var steam_game = game as Models.Games.Steam;
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

            bool any_visible = false;
            var child = content_box.get_first_child ();
            while (child != null) {
                if (child.get_visible ()) {
                    any_visible = true;
                    break;
                }
                child = child.get_next_sibling ();
            }
            this.set_sensitive (any_visible);
        }

        public override void dispose () {
            popover.unparent ();

            base.dispose ();
        }

        void extra_button_clicked () {
            popover.popup ();
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