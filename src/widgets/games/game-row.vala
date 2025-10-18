namespace ProtonPlus.Widgets {
	public class GameRow : Gtk.ListBoxRow {
		Gtk.Label title_label;
		Gtk.Label prefix_label;
		public CompatibilityToolDropDown compatibility_tool_dropdown;
		Gtk.Button launch_options_button;
		Gtk.Button anticheat_button;
		Gtk.Button protondb_button;
		ExtraButton extra_button;
		Gtk.Box content_box;
		public Models.Game game { get; set; }
		
		public bool selected { get; set; }

		public GameRow(Models.Game game, ListStore model, Gtk.PropertyExpression expression) {
			this.game = game;

			title_label = new Gtk.Label(game.name);
			title_label.set_tooltip_text(title_label.get_label());
			title_label.set_halign(Gtk.Align.START);
			title_label.set_hexpand(true);
			title_label.set_ellipsize (Pango.EllipsizeMode.END);

			prefix_label = new Gtk.Label(game.prefix.to_string());
			prefix_label.set_tooltip_text(prefix_label.get_label());
			prefix_label.set_max_width_chars (10);
			prefix_label.set_ellipsize (Pango.EllipsizeMode.END);
			prefix_label.set_selectable(true);
			prefix_label.set_size_request(110, 0);

			compatibility_tool_dropdown = new CompatibilityToolDropDown (game, model, expression);

			extra_button = new ExtraButton(game);

			content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
			content_box.set_margin_start(10);
			content_box.set_margin_end(10);
			content_box.set_margin_top(10);
			content_box.set_margin_bottom(10);
			content_box.set_valign(Gtk.Align.CENTER);
			content_box.append(title_label);
			content_box.append(prefix_label);
			content_box.append(compatibility_tool_dropdown);

			if (game is Models.Games.Steam)
				load_steam((Models.Games.Steam) game);

			content_box.append(extra_button);

			set_child(content_box);
		}

		void load_steam(Models.Games.Steam game) {
			launch_options_button = new Gtk.Button.from_icon_name("edit-symbolic");
			launch_options_button.set_tooltip_text(_("Modify the game launch options"));
			launch_options_button.add_css_class("flat");
			launch_options_button.clicked.connect(launch_options_button_clicked);

			anticheat_button = new Gtk.Button.from_icon_name("shield-symbolic");
			anticheat_button.set_tooltip_text(game.awacy_status);
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
				anticheat_button.set_tooltip_text(_("Unknown"));
				anticheat_button.set_sensitive(false);
				break;
			}

			protondb_button = new Gtk.Button.from_icon_name("proton-symbolic");
			protondb_button.set_tooltip_text(_("Open ProtonDB page"));
			protondb_button.add_css_class("flat");
			protondb_button.clicked.connect(protondb_button_clicked);
			protondb_button.set_sensitive(!game.is_non_steam);

			content_box.append(launch_options_button);
			content_box.append(anticheat_button);
			content_box.append(protondb_button);
		}

		void launch_options_button_clicked() {
			if (!(game is Models.Games.Steam))
				return;

			var dialog = new LaunchOptionsDialog(this);
			dialog.present(Application.window);
		}

		void anticheat_button_clicked() {
			if (!(game is Models.Games.Steam))
				return;

			var steam_game = (Models.Games.Steam) game;

			if (steam_game.awacy_name != null)
				Utils.System.open_uri("https://areweanticheatyet.com/game/%s".printf(steam_game.awacy_name));
		}

		void protondb_button_clicked() {
			if (!(game is Models.Games.Steam))
				return;

			var steam_game = (Models.Games.Steam) game;

			Utils.System.open_uri("https://www.protondb.com/app/%u".printf(steam_game.appid));
		}
	}
}
