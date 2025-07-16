namespace ProtonPlus.Widgets {
	public class ShortcutButton : Gtk.Button {
		Models.SteamProfile profile { get; set; }
		Adw.ButtonContent shortcut_button_content { get; set; }

		construct {
			shortcut_button_content = new Adw.ButtonContent();
			shortcut_button_content.set_icon_name("bookmark-plus-symbolic");

			clicked.connect(shortcut_button_clicked);

			add_css_class("flat");
			set_child(shortcut_button_content);
		}

		public void load(Models.SteamProfile profile) {
			this.profile = profile;

			refresh();
		}

		public void reset() {
			shortcut_button_content.set_label(_("Create shortcut"));
		}

		void refresh() {
			var shortcut_installed = profile.shortcut_file.get_installed_status();
			shortcut_button_content.set_label(!shortcut_installed ? _("Create shortcut") : _("Delete shortcut"));
			set_tooltip_text(!shortcut_installed ? _("Create a shortcut of ProtonPlus in Steam") : _("Delete the shortcut of ProtonPlus in Steam"));
		}

		void shortcut_button_clicked() {
			var installed = profile.shortcut_file.get_installed_status();

			if (installed) {
				var success = profile.shortcut_file.uninstall();
				if (!success) {
					var dialog = new Adw.AlertDialog(_("Error"), "%s\n%s".printf(_("When trying to delete the shortcut in Steam an error occurred."), _("Please report this issue on GitHub.")));
					dialog.add_response("ok", _("OK"));
					dialog.present(Application.window);
				}
				refresh();
			} else {
				profile.shortcut_file.install.begin((obj, res) => {
					var success = profile.shortcut_file.install.end(res);
					if (!success) {
						var dialog = new Adw.AlertDialog(_("Error"), "%s\n%s".printf(_("When trying to create the shortcut in Steam an error occurred."), _("Please report this issue on GitHub.")));
						dialog.add_response("ok", _("OK"));
						dialog.present(Application.window);
					}
					refresh();
				});
			}
		}
	}
}
