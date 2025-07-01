namespace ProtonPlus.Widgets {
	public class MassEditDialog : Adw.Dialog {
		Adw.HeaderBar header_bar { get; set; }
		Adw.ToolbarView toolbar_view { get; set; }
		Adw.WindowTitle window_title { get; set; }
		Gtk.Button apply_button { get; set; }
		Adw.SwitchRow modify_compatibility_tool_row { get; set; }
		CompatibilityToolRow compatibility_tool_row { get; set; }
		Adw.PreferencesGroup compatibility_tool_group { get; set; }
		Adw.SwitchRow modify_launch_options_row { get; set; }
		Adw.EntryRow launch_options_row { get; set; }
		Adw.PreferencesGroup launch_options_group { get; set; }
		Gtk.Label warning_label { get; set; }
		Gtk.Box content_box { get; set; }
		GameRow[] rows;

		public MassEditDialog(GameRow[] rows, ListStore model, Gtk.PropertyExpression expression) {
			this.rows = rows;

			window_title = new Adw.WindowTitle(_("Mass edit"), rows.length == 1 ? _("1 game selected") : _("%u games selected").printf(rows.length));

			apply_button = new Gtk.Button.with_label(_("Apply"));
			apply_button.set_tooltip_text(_("Apply the current modifications"));
			apply_button.clicked.connect(apply_button_clicked);

			header_bar = new Adw.HeaderBar();
			header_bar.pack_start(apply_button);
			header_bar.set_title_widget(window_title);

			modify_compatibility_tool_row = new Adw.SwitchRow();
			modify_compatibility_tool_row.set_title(_("Enabled"));
			modify_compatibility_tool_row.set_tooltip_text(_("Enable this if you want the mass edit to take the compatibility tool into account."));
			modify_compatibility_tool_row.notify["active"].connect(modify_row_active_changed);

			compatibility_tool_row = new CompatibilityToolRow (model, expression);
			
			compatibility_tool_group = new Adw.PreferencesGroup();
			compatibility_tool_group.set_title(_("Compatibility tool"));
			compatibility_tool_group.add(modify_compatibility_tool_row);
			compatibility_tool_group.add(compatibility_tool_row);

			modify_launch_options_row = new Adw.SwitchRow();
			modify_launch_options_row.set_title(_("Enabled"));
			modify_launch_options_row.set_tooltip_text(_("Enable this if you want the mass edit to take the launch options into account."));
			modify_launch_options_row.notify["active"].connect(modify_row_active_changed);

			launch_options_row = new Adw.EntryRow();
			launch_options_row.set_title(_("Enter your desired launch options"));

			launch_options_group = new Adw.PreferencesGroup();
			launch_options_group.set_title(_("Launch options"));
			launch_options_group.add(modify_launch_options_row);
			launch_options_group.add(launch_options_row);

			warning_label = new Gtk.Label(_("Enable all the options that you want the mass edit to take into account."));
			warning_label.add_css_class("warning");

			content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			content_box.set_margin_start(10);
			content_box.set_margin_end(10);
			content_box.set_margin_bottom(10);
			content_box.append(compatibility_tool_group);

			if (rows[0].game.launcher is Models.Launchers.Steam)
				content_box.append(launch_options_group);

			content_box.append(warning_label);

			toolbar_view = new Adw.ToolbarView();
			toolbar_view.add_top_bar(header_bar);
			toolbar_view.set_content(content_box);

			refresh();

			set_size_request(750, 0);
			set_child(toolbar_view);
		}

		void refresh() {
			var compatibility_tool_check = modify_compatibility_tool_row.get_active();
			var launch_options_check = modify_launch_options_row.get_active();

			apply_button.set_sensitive(compatibility_tool_check || launch_options_check);
			compatibility_tool_row.set_sensitive(compatibility_tool_check);
			launch_options_row.set_sensitive(launch_options_check);
		}

		void modify_row_active_changed() {
			refresh();
		}

		void apply_button_clicked() {
			var item = (Models.SimpleRunner) compatibility_tool_row.get_selected_item();
			var invalids = new List<string> ();

			foreach (var row in rows) {
				if (modify_compatibility_tool_row.get_active()) {
					var valids = new List<GameRow> ();

					var success = row.game.change_compatibility_tool(item.internal_title);
					if (!success && invalids.find(row.game.name) == null)
						invalids.append(row.game.name);
					else
						valids.append(row);

					if (valids.length() > 0) {
						foreach (var valid_row in valids) {
							valid_row.compatibility_tool_dropdown.skip = true;
							if (valid_row.game.compatibility_tool == _("Undefined")) {
								valid_row.compatibility_tool_dropdown.dropdown.set_selected(0);
							} else {
								for (var i = 0; i < valid_row.game.launcher.compatibility_tools.length(); i++) {
									if (valid_row.game.compatibility_tool == valid_row.game.launcher.compatibility_tools.nth_data(i).internal_title) {
										valid_row.compatibility_tool_dropdown.dropdown.set_selected(i + 1);
										break;
									}
								}
							}
						}
					}
				}

				if (row.game.launcher is Models.Launchers.Steam && modify_launch_options_row.get_active()) {
					var valids = new List<GameRow> ();

					var steam_game = (Models.Games.Steam) row.game;
					var steam_launcher = (Models.Launchers.Steam) steam_game.launcher;

					var success = steam_game.change_launch_options(launch_options_row.get_text(), steam_launcher.profile.localconfig_path);
					if (!success && invalids.find(row.game.name) == null)
						invalids.append(row.game.name);
					else
						valids.append(row);
				}
			}

			if (invalids.length() > 0) {
				var names = "";

				for (var i = 0; i < invalids.length(); i++) {
					names += "- %s".printf(invalids.nth_data(i));

					if (i != invalids.length() - 1)
						names += "\n";
				}

				var dialog = new Adw.AlertDialog(_("Error"), "%s\n\n%s\n\n%s".printf(_("When trying to change the compatibility tool/launch options of the selected games an error occured for the following games:"), names, _("Please report this issue on GitHub.")));
				dialog.add_response("ok", "OK");
				dialog.present(Application.window);
			}

			close();
		}
	}
}
