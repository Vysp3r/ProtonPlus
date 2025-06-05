namespace ProtonPlus.Widgets {
    public class GameRow : Gtk.ListBoxRow {
        public Gtk.DropDown compat_tool_dropdown { get; set; }
        Gtk.Button anticheat_button { get; set; }
        Gtk.Image protondb_image { get; set; }
        Gtk.Button protondb_button { get; set; }
        Gtk.Label title_label { get; set; }
        Gtk.Box box { get; set; }
        public Models.Game game { get; set; }
        public bool skip { get; set; }

        public GameRow(Models.Game game, ListStore model, Gtk.PropertyExpression expression) {
            this.game = game;

            compat_tool_dropdown = new Gtk.DropDown(model, expression);

            for (var i = 0; i < game.launcher.compatibility_tools.length(); i++) {
                if (game.launcher.compatibility_tools.nth_data(i).title == game.compat_tool) {
                    compat_tool_dropdown.set_selected(i);
                    break;
                }
            }

            compat_tool_dropdown.notify["selected-item"].connect(compat_tool_dropdown_selected_item_changed);

            anticheat_button = new Gtk.Button.from_icon_name("shield-symbolic");
            anticheat_button.set_tooltip_text(_("Open AreWeAntiCheatYet page"));
            anticheat_button.add_css_class("flat");
            anticheat_button.clicked.connect(anticheat_button_clicked);

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

            protondb_image = new Gtk.Image.from_resource("/com/vysp3r/ProtonPlus/proton.png");

            protondb_button = new Gtk.Button();
            protondb_button.set_child(protondb_image);
            protondb_button.set_tooltip_text(_("Open ProtonDB page"));
            protondb_button.add_css_class("flat");
            protondb_button.clicked.connect(protondb_button_clicked);

            title_label = new Gtk.Label(game.name);
            title_label.set_halign(Gtk.Align.START);
            title_label.set_hexpand(true);

            box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            box.set_margin_start(10);
            box.set_margin_end(10);
            box.set_margin_top(10);
            box.set_margin_bottom(10);
            box.set_valign(Gtk.Align.CENTER);
            box.append(title_label);
            box.append(compat_tool_dropdown);
            box.append(anticheat_button);
            box.append(protondb_button);

            set_child(box);
        }

        void anticheat_button_clicked() {
            if (game.awacy_name != null)
                Utils.System.open_url("https://areweanticheatyet.com/game/%s".printf(game.awacy_name));
        }

        void protondb_button_clicked() {
            Utils.System.open_url("https://www.protondb.com/app/%i".printf(game.appid));
        }

        void compat_tool_dropdown_selected_item_changed() {
            if (skip) {
                skip = false;
                return;
            }

            var item = (Models.SimpleRunner) compat_tool_dropdown.get_selected_item();

            var success = game.set_compatibility_tool(item.title);
            if (!success) {
                var dialog = new Adw.AlertDialog(null, "%s\n%s".printf(_("When trying to change the compatibility tool of %s an error occured.").printf(game.name), _("Please report this issue on GitHub.")));
                dialog.add_response("ok", "OK");
                dialog.present(Application.window);

                skip = true;

                for (var i = 0; i < game.launcher.compatibility_tools.length(); i++) {
                    if (game.compat_tool == game.launcher.compatibility_tools.nth_data(i).title) {
                        compat_tool_dropdown.set_selected(i);
                        break;
                    }
                }
            }
        }
    }
}