namespace ProtonPlus.Widgets {
    public class LaunchOptionsDialog : Adw.Dialog {
        Adw.HeaderBar header_bar { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Gtk.Button apply_button { get; set; }
        Gtk.Entry launch_options_entry { get; set; }
        GameRow row { get; set; }

        construct {
            window_title = new Adw.WindowTitle(_("Modify launch options"), "");

            apply_button = new Gtk.Button.with_label(_("Apply"));
            apply_button.set_tooltip_text(_("Apply the current modification"));
            apply_button.clicked.connect(apply_button_clicked);

            header_bar = new Adw.HeaderBar();
            header_bar.pack_start(apply_button);
            header_bar.set_title_widget(window_title);

            launch_options_entry = new Gtk.Entry();
            launch_options_entry.set_margin_start(10);
            launch_options_entry.set_margin_end(10);
            launch_options_entry.set_margin_top(10);
            launch_options_entry.set_margin_bottom(10);
            launch_options_entry.set_placeholder_text(_("Enter your desired launch options"));

            toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.set_content(launch_options_entry);

            set_size_request(750, 0);
            set_child(toolbar_view);
        }

        public LaunchOptionsDialog(GameRow row) {
            this.row = row;

            window_title.set_subtitle(row.game.name);
        }

        void apply_button_clicked() {
            var success = row.game.set_launch_options(launch_options_entry.get_text());
            if (!success) {
                var dialog = new Adw.AlertDialog(_("Error"), "%s\n\n%s".printf(_("When trying to change the launch options of %s an error occured.").printf(row.game.name), _("Please report this issue on GitHub.")));
                dialog.add_response("ok", "OK");
                dialog.present(Application.window);
            }

            close();
        }
    }
}