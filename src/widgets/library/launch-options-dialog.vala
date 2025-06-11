namespace ProtonPlus.Widgets {
    public class LaunchOptionsDialog : Adw.Dialog {
        Adw.HeaderBar header_bar { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Gtk.Button apply_button { get; set; }
        Adw.EntryRow launch_options_entry_row { get; set; }
        Adw.PreferencesGroup launch_options_group { get; set; }
        GameRow row { get; set; }

        construct {
            window_title = new Adw.WindowTitle(_("Modify launch options"), "");

            apply_button = new Gtk.Button.with_label(_("Apply"));
            apply_button.set_tooltip_text(_("Apply the current modification"));
            apply_button.clicked.connect(apply_button_clicked);

            header_bar = new Adw.HeaderBar();
            header_bar.pack_start(apply_button);
            header_bar.set_title_widget(window_title);

            launch_options_entry_row = new Adw.EntryRow();
            
            launch_options_entry_row.set_title(_("Enter your desired launch options"));

            launch_options_group = new Adw.PreferencesGroup();
            launch_options_group.set_margin_start(10);
            launch_options_group.set_margin_end(10);
            launch_options_group.set_margin_top(10);
            launch_options_group.set_margin_bottom(10);
            launch_options_group.add(launch_options_entry_row);

            toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.set_content(launch_options_group);

            set_size_request(750, 0);
            set_child(toolbar_view);
        }

        public LaunchOptionsDialog(GameRow row) {
            this.row = row;

            window_title.set_subtitle(row.game.name);

            var steam_game = (Models.Games.Steam) row.game;

            launch_options_entry_row.set_text(steam_game.launch_options);
        }

        void apply_button_clicked() {
            var steam_game = (Models.Games.Steam) row.game;
            var steam_launcher = (Models.Launchers.Steam) steam_game.launcher;

            var success = steam_game.change_launch_options(launch_options_entry_row.get_text(), steam_launcher.profile.localconfig_path);
            if (!success) {
                var dialog = new Adw.AlertDialog(_("Error"), "%s\n\n%s".printf(_("When trying to change the launch options of %s an error occured.").printf(row.game.name), _("Please report this issue on GitHub.")));
                dialog.add_response("ok", "OK");
                dialog.present(Application.window);
            }

            close();
        }
    }
}