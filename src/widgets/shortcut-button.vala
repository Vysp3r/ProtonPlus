namespace ProtonPlus.Widgets {
    public class ShortcutButton : Gtk.Button {
        Models.Launchers.Steam launcher { get; set; }
        Adw.ButtonContent shortcut_button_content { get; set; }

        construct {
            shortcut_button_content = new Adw.ButtonContent();
            shortcut_button_content.set_icon_name("bookmark-plus-symbolic");

            set_child(shortcut_button_content);
            clicked.connect(shortcut_button_clicked);
        }

        public void load (Models.Launchers.Steam launcher) {
            this.launcher = launcher;

            refresh();
        }

        void refresh() {
            var shortcut_installed = launcher.check_shortcuts_files();
            shortcut_button_content.set_label(!shortcut_installed ? _("Create shortcut") : _("Remove shortcut"));
            set_tooltip_text(!shortcut_installed ? _("Create a shortcut of ProtonPlus in Steam") : _("Remove the shortcut of ProtonPlus in Steam"));
        }

        void shortcut_button_clicked() {
            var installed = launcher.check_shortcuts_files();

            foreach (var file in launcher.shortcuts_files) {
                var status = file.get_installed_status();

                if (installed) {
                    if (status) {
                        var success = launcher.uninstall_shortcut(file);
                        if (!success) {
                            var dialog = new Adw.AlertDialog(_("Error"), "%s\n%s".printf(_("When trying to remove the shortcut in Steam an error occured."), _("Please report this issue on GitHub.")));
                            dialog.add_response("ok", "OK");
                            dialog.present(Application.window);
                        }
                    } else {
                        message("remove but not installed");
                    }
                } else {
                    if (!status) {
                        var success = launcher.install_shortcut(file);
                        if (!success) {
                            var dialog = new Adw.AlertDialog(_("Error"), "%s\n%s".printf(_("When trying to create the shortcut in Steam an error occured."), _("Please report this issue on GitHub.")));
                            dialog.add_response("ok", "OK");
                            dialog.present(Application.window);
                        }
                    } else {
                        message("create but already installed");
                    }
                }
            }

            refresh();
        }
    }
}