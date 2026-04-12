namespace ProtonPlus.Widgets {
	public class MassEditView : Gtk.Box {
		public signal void back_requested ();

		Adw.WindowTitle window_title { get; set; }
		Gtk.Button back_button { get; set; }
		Gtk.Button clear_button { get; set; }
		Gtk.Label advanced_label { get; set; }
		Gtk.Switch advanced_switch { get; set; }
		Gtk.Box advanced_box { get; set; }
		Gtk.Button apply_button { get; set; }
		Adw.HeaderBar header_bar { get; set; }
		Adw.Clamp content_clamp { get; set; }
		Gtk.ScrolledWindow scrolled_window { get; set; }
		Adw.SwitchRow modify_compatibility_tool_row { get; set; }
		CompatibilityToolRow compatibility_tool_row { get; set; }
		Adw.PreferencesGroup compatibility_tool_group { get; set; }
		Adw.SwitchRow modify_launch_options_row { get; set; }
		Adw.PreferencesGroup launch_options_group { get; set; }
		LaunchOptionsEditor launch_options_editor { get; set; }
		Gtk.Box content_box { get; set; }
		Adw.ToolbarView toolbar_view { get; set; }
		GameRow[] rows;

		construct {
			set_orientation (Gtk.Orientation.VERTICAL);

			window_title = new Adw.WindowTitle (_("Modify launch options"), "");

			back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic");
			back_button.add_css_class ("flat");
			back_button.set_tooltip_text (_("Back"));
			back_button.clicked.connect (() => back_requested ());

			clear_button = new Gtk.Button.from_icon_name ("eraser-symbolic");
			clear_button.add_css_class ("flat");
			clear_button.add_css_class ("clear-button");
			clear_button.set_tooltip_text (_("Clear the current launch options"));
			clear_button.clicked.connect (clear_button_clicked);

			advanced_label = new Gtk.Label (_("Advanced"));

			advanced_switch = new Gtk.Switch ();
			advanced_switch.set_valign (Gtk.Align.CENTER);

			advanced_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			advanced_box.set_valign (Gtk.Align.CENTER);
			advanced_box.append (advanced_label);
			advanced_box.append (advanced_switch);

			apply_button = new Gtk.Button.from_icon_name ("floppy-disk-symbolic");
			apply_button.add_css_class ("flat");
			apply_button.add_css_class ("apply-button");
			apply_button.set_tooltip_text (_("Apply the current modifications"));
			apply_button.clicked.connect (apply_button_clicked);

			header_bar = new Adw.HeaderBar ();
			header_bar.set_title_widget (window_title);
			header_bar.pack_start (back_button);
			header_bar.pack_start (clear_button);
			header_bar.pack_end (apply_button);
			header_bar.pack_end (advanced_box);

			modify_compatibility_tool_row = new Adw.SwitchRow();
			modify_compatibility_tool_row.set_title(_("Enabled"));
			modify_compatibility_tool_row.set_tooltip_text(_("Enable this if you want the mass edit to take the compatibility tool into account."));
			modify_compatibility_tool_row.notify["active"].connect(modify_row_active_changed);
			
			compatibility_tool_group = new Adw.PreferencesGroup();
			compatibility_tool_group.set_title(_("Compatibility tool"));
			compatibility_tool_group.add(modify_compatibility_tool_row);

			modify_launch_options_row = new Adw.SwitchRow();
			modify_launch_options_row.set_title(_("Enabled"));
			modify_launch_options_row.set_tooltip_text(_("Enable this if you want the mass edit to take the launch options into account."));
			modify_launch_options_row.notify["active"].connect(modify_row_active_changed);

			launch_options_editor = new LaunchOptionsEditor ();
			advanced_switch.notify["active"].connect (() => launch_options_editor.set_advanced_visible (advanced_switch.get_active ()));

			launch_options_group = new Adw.PreferencesGroup();
			launch_options_group.set_title(_("Launch options"));
			launch_options_group.add(modify_launch_options_row);

			content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
			content_box.append(compatibility_tool_group);
			content_box.append(launch_options_group);
			content_box.append(launch_options_editor);

			content_clamp = new Adw.Clamp ();
			content_clamp.add_css_class ("content-clamp");
			content_clamp.set_maximum_size (975);
			content_clamp.set_child (content_box);

			scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.set_hexpand (true);
			scrolled_window.set_vexpand (true);
			scrolled_window.set_child (content_clamp);

			toolbar_view = new Adw.ToolbarView ();
			toolbar_view.add_top_bar (header_bar);
			toolbar_view.set_content (scrolled_window);

			append (toolbar_view);
		}

		public void load (GameRow[] rows, ListStore model, Gtk.PropertyExpression expression) {
			this.rows = rows;

			window_title.set_subtitle (rows.length == 1 ? _("1 game selected") : _("%u games selected").printf(rows.length));

			if (compatibility_tool_row != null)
				compatibility_tool_group.remove (compatibility_tool_row);

			compatibility_tool_row = new CompatibilityToolRow (model, expression);
			compatibility_tool_group.add (compatibility_tool_row);

			modify_compatibility_tool_row.set_active (false);
			modify_launch_options_row.set_active (false);
			advanced_switch.set_active (false);
			launch_options_editor.set_text ("");

			var has_steam_launch_options = rows[0].game.launcher is Models.Launchers.Steam;
			launch_options_group.set_visible (has_steam_launch_options);
			launch_options_editor.set_visible (has_steam_launch_options);

			refresh ();
		}

		void refresh() {
			var compatibility_tool_check = modify_compatibility_tool_row.get_active();
			var launch_options_check = modify_launch_options_row.get_active();

			clear_button.set_sensitive (compatibility_tool_check || launch_options_check || launch_options_editor.has_clearable_state ());
			apply_button.set_sensitive(compatibility_tool_check || launch_options_check);
			compatibility_tool_row.set_sensitive(compatibility_tool_check);
			launch_options_editor.set_sensitive(launch_options_check);
			advanced_switch.set_sensitive(launch_options_check);
			advanced_label.set_sensitive (launch_options_check);
		}

		void modify_row_active_changed() {
			refresh();
		}

		void clear_button_clicked () {
			modify_compatibility_tool_row.set_active (false);
			modify_launch_options_row.set_active (false);
			launch_options_editor.clear ();
			refresh ();
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
								for (var i = 0; i < valid_row.game.launcher.compatibility_tools.size; i++) {
									if (valid_row.game.compatibility_tool == valid_row.game.launcher.compatibility_tools[i].internal_title) {
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

					var success = steam_game.change_launch_options(launch_options_editor.get_text(), steam_launcher.profile.localconfig_path);
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

				var dialog = new ErrorDialog (_("Couldn't change the compatibility tool/launch options of the selected games"), "%s\n\n%s\n\n%s".printf(_("The following games had an issue:"), names, _("Please report this issue on GitHub.")));
				dialog.present(Application.window);
			}

			back_requested ();
		}
	}
}
