namespace ProtonPlus.Widgets {
    public class MassEditDialog : Adw.Dialog {
        Adw.HeaderBar header_bar { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Gtk.DropDown compat_tool_dropdown { get; set; }
        Gtk.Button apply_button { get; set; }
        Gtk.Box box { get; set; }
        GameRow[] rows;

        public MassEditDialog(GameRow[] rows, ListStore model, Gtk.PropertyExpression expression) {
            this.rows = rows;

            window_title = new Adw.WindowTitle("Mass edit", "%u %s".printf(rows.length, _("games selected")));

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
            var item = (Models.SimpleRunner) compat_tool_dropdown.get_selected_item();
            var valids = new List<GameRow> ();
            var invalids = new List<string> ();

            foreach (var row in rows) {
                var success = row.game.set_compatibility_tool(item.title);
                if (!success)
                    invalids.append(row.game.name);
                else
                    valids.append(row);
            }

            if (valids.length() > 0) {
                foreach (var row in valids) {
                    row.skip = true;
                    for (var i = 0; i < row.game.launcher.compatibility_tools.length(); i++) {
                        if (row.game.compat_tool == row.game.launcher.compatibility_tools.nth_data(i).title) {
                            row.compat_tool_dropdown.set_selected(i);
                            break;
                        }
                    }
                }
            }

            if (invalids.length() > 0) {
                var names = "";

                for (var i = 0; i < invalids.length(); i++) {
                    names += "- %s".printf(invalids.nth_data(i));

                    if (i != invalids.length() - 1)
                        names += "\n";
                }

                var dialog = new Adw.AlertDialog(null, "%s:\n%s\n%s".printf(_("When trying to change the compatibility tool of the selected games an error occured for the following games"), names, _("Please report this issue on GitHub.")));
                dialog.add_response("ok", "OK");
                dialog.present(Application.window);
            }

            close();
        }
    }
}