namespace ProtonPlus.Widgets {
	public class GamesBox : Gtk.Box {
		public delegate void load_steam_profile_func(Models.SteamProfile profile);

		public bool active { get; set; }
		bool error { get; set; }
		bool invalid { get; set; }
		Models.Launcher launcher;

		Gtk.Image image;
		Adw.StatusPage status_page;
		ShortcutButton shortcut_button;
		MassEditButton mass_edit_button;
		DefaultToolButton default_tool_button;
		SwitchProfileButton switch_profile_button;
		SelectButton select_button;
		UnselectButton unselect_button;
		Gtk.FlowBox flow_box;
		Gtk.Label name_label;
		Gtk.Label prefix_label;
		Gtk.Label compatibility_tool_label;
		Gtk.Label other_label;
		Gtk.Box header_box;
		Gtk.Box headered_list_box;
		Gtk.ScrolledWindow scrolled_window;
		Gtk.ListBox game_list_box;
		Gtk.Label warning_label;
		Gtk.Spinner spinner;
		Gtk.Overlay overlay;
		ListStore model;
		Gtk.PropertyExpression expression;

		construct {
			image = new Gtk.Image();

			status_page = new Adw.StatusPage();
			status_page.set_visible(false);

			game_list_box = new Gtk.ListBox();
			game_list_box.set_selection_mode(Gtk.SelectionMode.MULTIPLE);
			game_list_box.add_css_class("boxed-list");
			game_list_box.add_css_class("list-content");
			game_list_box.row_activated.connect(game_list_box_row_activated);

			spinner = new Gtk.Spinner();
			spinner.set_halign(Gtk.Align.CENTER);
			spinner.set_valign(Gtk.Align.CENTER);
			spinner.set_size_request(200, 200);

			overlay = new Gtk.Overlay();
			overlay.set_child(game_list_box);

			scrolled_window = new Gtk.ScrolledWindow();
			scrolled_window.set_vexpand(true);
			scrolled_window.set_child(overlay);
			scrolled_window.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

			warning_label = new Gtk.Label(_("Close the Steam client beforehand so that the changes can be applied."));
			warning_label.add_css_class("warning");

			shortcut_button = new ShortcutButton();

			mass_edit_button = new MassEditButton(game_list_box);

			select_button = new SelectButton(game_list_box);

			unselect_button = new UnselectButton(game_list_box);

			default_tool_button = new DefaultToolButton();

			switch_profile_button = new SwitchProfileButton();

			flow_box = new Gtk.FlowBox();
			flow_box.add_css_class("card");
			flow_box.add_css_class("p-10");
			flow_box.set_halign(Gtk.Align.CENTER);
			flow_box.append(shortcut_button);
			flow_box.append(mass_edit_button);
			flow_box.append(select_button);
			flow_box.append(unselect_button);
			flow_box.append(default_tool_button);
			flow_box.append(switch_profile_button);
			flow_box.set_selection_mode(Gtk.SelectionMode.NONE);

			var name_label_gesture = new Gtk.GestureClick();
			name_label_gesture.pressed.connect(name_label_clicked);

			name_label = new Gtk.Label(_("Name"));
			name_label.set_hexpand(true);
			name_label.add_controller(name_label_gesture);

			prefix_label = new Gtk.Label(_("Prefix"));
			prefix_label.set_margin_end(10);
			prefix_label.set_size_request(100, 0);

			var compatibility_tool_label_gesture = new Gtk.GestureClick();
			compatibility_tool_label_gesture.pressed.connect(compatibility_tool_label_clicked);

			compatibility_tool_label = new Gtk.Label(_("Compatibility tool"));
			compatibility_tool_label.set_size_request(350, 0);
			compatibility_tool_label.add_controller(compatibility_tool_label_gesture);

			other_label = new Gtk.Label(_("Other"));
			other_label.set_size_request(175, 0);

			header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			header_box.set_hexpand(true);
			header_box.add_css_class("card");
			header_box.add_css_class("list-header");
			header_box.append(name_label);
			header_box.append(prefix_label);
			header_box.append(compatibility_tool_label);
			header_box.append(other_label);

			headered_list_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			headered_list_box.add_css_class("card");
			headered_list_box.add_css_class("transparent-card");
			headered_list_box.append(header_box);
			headered_list_box.append(scrolled_window);

			notify["active"].connect(() => {
				if (!active || error || !(launcher is Models.Launchers.Steam))
					return;

				var steam_launcher = launcher as Models.Launchers.Steam;

				if (steam_launcher.profiles.length() == 0) {
					error = true;
					show_status_box("bug-symbolic", _("An error occurred"), "%s\n%s\n%s".printf(_("No profile was found."), _("Make sure to connect yourself at least once on Steam."), _("If you think this is an issue, make sure to report this on GitHub.")));
				} else if (steam_launcher.profiles.length() > 1) {
					game_list_box.remove_all();

					var dialog = new ProfileDialog(steam_launcher, load_steam_profile);
					dialog.present(Application.window);
				} else {
					load_steam_profile(steam_launcher.profiles.nth_data(0));
				}
			});

			set_orientation(Gtk.Orientation.VERTICAL);
			set_spacing(12);
			set_margin_top(7);
			set_margin_bottom(12);
			set_margin_start(12);
			set_margin_end(12);

			append(flow_box);
			append(headered_list_box);
			append(warning_label);
			append(status_page);
		}

		public void set_selected_launcher(Models.Launcher launcher) {
			this.launcher = launcher;

			shortcut_button.set_visible(false);
			warning_label.set_visible(false);
			switch_profile_button.set_visible(false);

			if (launcher.has_library_support) {
				if (invalid) {
					show_normal();

					invalid = false;
				}

				if (launcher is Models.Launchers.Steam) {
					var steam_launcher = (Models.Launchers.Steam) launcher;

					shortcut_button.reset();
					shortcut_button.set_visible(true);

					warning_label.set_visible(true);

					default_tool_button.set_visible(steam_launcher.enable_default_compatibility_tool);
					default_tool_button.load(steam_launcher);

					if (steam_launcher.profiles.length() > 1) {
						switch_profile_button.set_visible(true);
						switch_profile_button.load(steam_launcher, load_steam_profile, game_list_box);
					}

					notify_property("active");                     // Ensure that when the launcher is changed, but you're in the Games tab the profile dialog still shows up
				} else {
					load_games();
				}
			} else {
				invalid = true;
				show_status_box(launcher.icon_path, _("Unsuported launcher"), "%s\n%s".printf(_("%s is currently not supported.").printf(launcher.title), _("If you want me to speed up the development make sure to show your support!")), true);
			}
		}

		void show_normal() {
			error = false;

			flow_box.set_visible(true);
			headered_list_box.set_visible(true);

			status_page.set_visible(false);
		}

		void show_status_box(string icon, string title, string description, bool is_image = false) {
			flow_box.set_visible(false);
			headered_list_box.set_visible(false);
			warning_label.set_visible(false);

			if (is_image)
				image.set_from_resource(icon);
			else
				image.set_from_icon_name(icon);

			status_page.set_vexpand(true);
			status_page.set_hexpand(true);
			status_page.set_title(title);
			status_page.set_description(description);
			status_page.set_paintable(image.get_paintable());
			status_page.set_visible(true);
		}

		void load_games() {
			if (!spinner.spinning)
				spinner.start();

			game_list_box.remove_all();

			overlay.add_overlay(spinner);

			model = new ListStore(typeof (Models.SimpleRunner));
			model.append(new Models.SimpleRunner(_("Undefined"), _("Undefined")));
			foreach (var ct in launcher.compatibility_tools)
				model.append(ct);

			expression = new Gtk.PropertyExpression(typeof (Models.SimpleRunner), null, "display_title");

			mass_edit_button.load(model, expression);

			foreach (var game in launcher.games) {
				var game_row = new GameRow(game, model, expression);

				game_list_box.append(game_row);
			}

			name_label_clicked();

			overlay.remove_overlay(spinner);

			spinner.stop();
		}

		void load_steam_profile(Models.SteamProfile profile) {
			spinner.start();

			shortcut_button.load(profile);

			var steam_launcher = (Models.Launchers.Steam) launcher;
			steam_launcher.switch_profile.begin(profile, (obj, res) => {
				load_games();
			});
		}

		void game_list_box_row_activated(Gtk.ListBoxRow? row) {
			if (row == null || !(row is GameRow))
				return;

			var game_row = (GameRow) row;

			if (game_row.selected) {
				game_row.selected = false;
				game_list_box.unselect_row(game_row);
			} else {
				game_row.selected = true;
			}
		}

		void name_label_clicked() {
			game_list_box.set_sort_func((row1, row2) => {
				var name1 = ((GameRow) row1).game.name;
				var name2 = ((GameRow) row2).game.name;

				return strcmp(name1, name2);
			});
		}

		void compatibility_tool_label_clicked() {
			game_list_box.set_sort_func((row1, row2) => {
				var name1 = ((GameRow) row1).game.compatibility_tool;
				var name2 = ((GameRow) row2).game.compatibility_tool;

				if (name1 == _("Undefined"))
					name1 = "zzzz";

				if (name2 == _("Undefined"))
					name2 = "zzzz";

				return strcmp(name1, name2);
			});
		}
	}
}