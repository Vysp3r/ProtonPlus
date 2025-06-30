namespace ProtonPlus.Widgets {
	public class GamesBox : Gtk.Box {
		public delegate void load_steam_profile_func(Models.SteamProfile profile);
		public bool active { get; set; }
		bool error { get; set; }
		Models.Launcher launcher;

		Adw.StatusPage status_page;
		ShortcutButton shortcut_button;
		MassEditButton mass_edit_button;
		DefaultToolButton default_tool_button;
		SelectButton select_button;
		UnselectButton unselect_button;
		SortByNameButton sort_by_name_button;
		SortByToolButton sort_by_tool_button;
		Gtk.FlowBox flow_box;
		Gtk.Label name_label;
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
			status_page = new Adw.StatusPage ();

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
			scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);

			warning_label = new Gtk.Label(_("Close the Steam client beforehand so that the changes can be applied."));
			warning_label.add_css_class("warning");

			shortcut_button = new ShortcutButton();

			mass_edit_button = new MassEditButton(game_list_box);

			select_button = new SelectButton(game_list_box);

			unselect_button = new UnselectButton(game_list_box);

			sort_by_name_button = new SortByNameButton(game_list_box);

			sort_by_tool_button = new SortByToolButton(game_list_box);

			default_tool_button = new DefaultToolButton();

			flow_box = new Gtk.FlowBox();
			flow_box.add_css_class("card");
			flow_box.add_css_class("p-10");
			flow_box.set_halign(Gtk.Align.CENTER);
			flow_box.append(shortcut_button);
			flow_box.append(mass_edit_button);
			flow_box.append(select_button);
			flow_box.append(unselect_button);
			flow_box.append(sort_by_name_button);
			flow_box.append(sort_by_tool_button);
			flow_box.append(default_tool_button);
			flow_box.set_selection_mode(Gtk.SelectionMode.NONE);

			name_label = new Gtk.Label(_("Name"));
			name_label.set_hexpand(true);

			compatibility_tool_label = new Gtk.Label(_("Compatibility tool"));
			compatibility_tool_label.set_size_request(350, 0);

			other_label = new Gtk.Label(_("Other"));
			other_label.set_size_request(175, 0);

			header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			header_box.set_hexpand(true);
			header_box.add_css_class("card");
			header_box.add_css_class("list-header");
			header_box.append(name_label);
			header_box.append(compatibility_tool_label);
			header_box.append(other_label);

			headered_list_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			headered_list_box.add_css_class("card");
			headered_list_box.add_css_class("transparent-bg");
			headered_list_box.append(header_box);
			headered_list_box.append(scrolled_window);

			notify["active"].connect(() => {
				if (!active || error || !(launcher is Models.Launchers.Steam))
					return;

				var steam_launcher = launcher as Models.Launchers.Steam;

				if (steam_launcher.profiles.length() == 0) {
					show_status_box("%s\n%s\n%s".printf(_("No profile was found."), _("Make sure to connect yourself at least once on Steam."), _("If you think this is an issue, make sure to report this on GitHub.")));
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

			show_normal();
		}

		public void set_selected_launcher(Models.Launcher launcher) {
			this.launcher = launcher;

			game_list_box.remove_all();

			if (launcher is Models.Launchers.Steam) {
				var steam_launcher = (Models.Launchers.Steam) launcher;

				shortcut_button.reset();
				shortcut_button.set_visible(true);

				warning_label.set_visible(true);

				default_tool_button.load(steam_launcher);
			} else {
				load_games();
			}
		}

		void show_normal () {
			error = false;

			if (flow_box.get_parent() == null)
				append(flow_box);
			if (headered_list_box.get_parent() == null)
				append(headered_list_box);
			if (warning_label.get_parent() == null)
				append(warning_label);

			if (status_page.get_parent() != null)
				remove(status_page);	
		}

		void show_status_box (string description) {
			error = true;

			if (flow_box.get_parent() != null)
				remove(flow_box);
			if (headered_list_box.get_parent() != null)
				remove(headered_list_box);
			if (warning_label.get_parent() != null)
				remove(warning_label);

			status_page.set_vexpand (true);
			status_page.set_hexpand (true);
			status_page.set_icon_name ("bug-symbolic");
			status_page.set_title (_("An error occured"));
			status_page.set_description (description);

			if (status_page.get_parent() == null)
				append(status_page);		
		}

		void load_games() {
			spinner.start();

			overlay.add_overlay(spinner);

			launcher.load_game_library.begin((obj, res) => {
				var loaded = launcher.load_game_library.end(res);

				if (loaded) {
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

					if (launcher is Models.Launchers.Steam) {
						var steam_launcher = (Models.Launchers.Steam) launcher;
						default_tool_button.set_visible(steam_launcher.enable_default_compatibility_tool);
					}
					
					sort_by_name_button.clicked();
				} else {
					show_status_box("%s\n%s".printf(_("The library failed loading."), _("Please report this issue on GitHub.")));
				}

				overlay.remove_overlay(spinner);

				spinner.stop();
			});
		}

		void load_steam_profile(Models.SteamProfile profile) {
			var steam_launcher = (Models.Launchers.Steam) launcher;
			steam_launcher.profile = profile;

			shortcut_button.load(profile);

			load_games();
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
	}
}
