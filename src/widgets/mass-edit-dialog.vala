namespace ProtonPlus.Widgets {
    public class MassEditDialog : Adw.Dialog {
        Adw.HeaderBar header_bar { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Gtk.DropDown compat_tool_dropdown { get; set; }
        Gtk.Button apply_button { get; set; }
        Gtk.Box box { get; set; }
        Models.Game[] games;
        public signal void reload ();

        public MassEditDialog(Models.Game[] games, ListStore model, Gtk.PropertyExpression expression) {
            this.games = games;

            window_title = new Adw.WindowTitle("Mass edit", "%u %s".printf(games.length, _("games selected")));

            apply_button = new Gtk.Button.with_label(_("Apply"));
            apply_button.clicked.connect(apply_button_clicked);

            header_bar = new Adw.HeaderBar();
            header_bar.pack_start(apply_button);
            header_bar.set_title_widget(window_title);

            compat_tool_dropdown = new Gtk.DropDown(model, expression);
            compat_tool_dropdown.set_margin_start(10);
            compat_tool_dropdown.set_margin_end(10);
            compat_tool_dropdown.set_margin_top(10);
            compat_tool_dropdown.set_margin_bottom(10);

            toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.set_content(compat_tool_dropdown);

            set_child(toolbar_view);
        }

        void apply_button_clicked() {
            var item = (Models.Launchers.Steam.RunnerDropDownItem) compat_tool_dropdown.get_selected_item();
            var success = true;

            foreach (var game in games) {
                message(game.name + " - " + game.appid.to_string());
                success = game.set_compatibility_tool(item.title);
                if (!success)
                    break;
            }

            if (!success) {
                var dialog = new Adw.AlertDialog(_("An error occured"), "%s\n%s".printf(_("When trying to change the compatibility tool of a game an error occured."), _("Please report this issue on GitHub.")));
                dialog.add_response("ok", "OK");
                dialog.present(Application.window);
            }

            reload();

            close();
        }
    }
}