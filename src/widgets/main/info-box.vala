namespace ProtonPlus.Widgets {
	public class InfoBox : Gtk.Box {
		Menu menu { get; set; }
		Gtk.MenuButton menu_button { get; set; }
		Adw.WindowTitle window_title { get; set; }
		Adw.HeaderBar header { get; set; }
		Adw.ToolbarView toolbar_view { get; set; }
		LauncherBox launcher_box { get; set; }

		construct {
			set_orientation (Gtk.Orientation.VERTICAL);

			window_title = new Adw.WindowTitle ("", "");

			var item = new MenuItem (_("_Installed Only"), null);
			item.set_action_and_target ("win.set-installed-only", "b");

			var filters_section = new Menu ();
			filters_section.append_item (item);

			var other_section = new Menu ();
			other_section.append (_("_Keyboard Shortcuts"), "win.show-help-overlay");
			other_section.append (_("_About ProtonPlus"), "app.about");

			menu = new Menu ();
			menu.append_section (null, filters_section);
			menu.append_section (null, other_section);

			menu_button = new Gtk.MenuButton ();
			menu_button.set_tooltip_text (_("Main Menu"));
			menu_button.set_icon_name ("open-menu-symbolic");
			menu_button.set_menu_model (menu);

			header = new Adw.HeaderBar ();
			header.set_title_widget (window_title);
			header.pack_end (menu_button);

			launcher_box = new LauncherBox ();

			toolbar_view = new Adw.ToolbarView ();
			toolbar_view.add_top_bar (header);
			toolbar_view.set_content (launcher_box);

			append (toolbar_view);
		}

		public void switch_mode (bool mode) {
			launcher_box.switch_mode (mode);
		}

		public void load (Models.Launcher launcher, bool installed_only) {
			window_title.set_title (launcher.title);

			launcher_box.load (launcher, installed_only);
		}
	}
}
