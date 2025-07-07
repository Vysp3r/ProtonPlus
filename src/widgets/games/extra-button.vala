namespace ProtonPlus.Widgets {
	public class ExtraButton : Gtk.Button {
		Models.Game game;
		Gtk.Button open_install_directory_button;
		Gtk.Button open_prefix_directory_button;
		Gtk.Button open_protontricks_button;
		Gtk.Box content_box;
		Gtk.Popover popover;

		construct {
			open_install_directory_button = new Gtk.Button.with_label(_("Open install directory"));
			open_install_directory_button.clicked.connect(open_install_directory_button_clicked);

			open_prefix_directory_button = new Gtk.Button.with_label(_("Open prefix directory"));
			open_prefix_directory_button.clicked.connect(open_prefix_directory_button_clicked);

			open_protontricks_button = new Gtk.Button.with_label(_("Open in protontricks"));
			open_protontricks_button.clicked.connect(open_protontricks_button_clicked);

			content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
			content_box.append(open_install_directory_button);
			content_box.append(open_prefix_directory_button);

			popover = new Gtk.Popover();
			popover.set_autohide(true);
			popover.set_parent(this);
			popover.set_child(content_box);

			clicked.connect(extra_button_clicked);

			set_icon_name("dots-symbolic");
			set_tooltip_text(_("Open menu"));
			add_css_class("flat");
		}

		public ExtraButton(Models.Game game) {
			this.game = game;

			if (game is Models.Games.Steam && Globals.PROTONTRICKS_EXEC != null)
				content_box.append(open_protontricks_button);
		}

		public override void dispose() {
			popover.unparent();

			base.dispose();
		}

		void extra_button_clicked() {
			popover.popup();
		}

		void open_install_directory_button_clicked() {
			Utils.System.open_uri("file://%s".printf(game.installdir));

			popover.popdown();
		}

		void open_prefix_directory_button_clicked() {
			Utils.System.open_uri("file://%s".printf(game.prefixdir));

			popover.popdown();
		}

		void open_protontricks_button_clicked() {
			var steam_game = game as Models.Games.Steam;

			Utils.System.run_command.begin("%s %i --gui".printf(Globals.PROTONTRICKS_EXEC, steam_game.appid));

			popover.popdown();
		}
	}
}