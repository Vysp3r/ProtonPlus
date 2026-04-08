namespace ProtonPlus.Widgets {
	public class MassEditView : Gtk.Box {
		public signal void back_requested ();

		Gtk.CenterBox page_header { get; set; }
		Adw.Clamp header_clamp { get; set; }
		Adw.Clamp content_clamp { get; set; }
		Gtk.Box title_box { get; set; }
		Gtk.Box header_start_box { get; set; }
		Gtk.Box actions_box { get; set; }
		Gtk.Box advanced_box { get; set; }
		Gtk.Label title_label { get; set; }
		Gtk.Label subtitle_label { get; set; }
		Gtk.Label advanced_label { get; set; }
		Gtk.Button back_button { get; set; }
		Gtk.Button clear_button { get; set; }
		Gtk.Switch advanced_switch { get; set; }
		Gtk.Button apply_button { get; set; }
		Gtk.ScrolledWindow scrolled_window { get; set; }
		Adw.SwitchRow modify_compatibility_tool_row { get; set; }
		CompatibilityToolRow compatibility_tool_row { get; set; }
		Adw.PreferencesGroup compatibility_tool_group { get; set; }
		Adw.SwitchRow modify_launch_options_row { get; set; }
		Adw.PreferencesGroup launch_options_group { get; set; }
		LaunchOptionsEditor launch_options_editor { get; set; }
		Gtk.Label warning_label { get; set; }
		Gtk.Box content_box { get; set; }
		GameRow[] rows;

		construct {
			set_orientation (Gtk.Orientation.VERTICAL);
			set_hexpand (true);
			set_vexpand (true);
			set_spacing (10);

			title_label = new Gtk.Label (_("Mass edit"));
			title_label.add_css_class ("title-3");
			title_label.set_halign (Gtk.Align.CENTER);

			subtitle_label = new Gtk.Label ("");
			subtitle_label.add_css_class ("dim-label");
			subtitle_label.set_halign (Gtk.Align.CENTER);

			title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
			title_box.set_hexpand (true);
			title_box.append (title_label);
			title_box.append (subtitle_label);

			back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic");
			back_button.add_css_class ("flat");
			back_button.set_tooltip_text (_("Back"));
			back_button.clicked.connect (() => back_requested ());

			clear_button = new Gtk.Button.with_label (_("Clear"));
			clear_button.add_css_class ("flat");
			clear_button.set_tooltip_text (_("Clear the current mass edit selections"));
			clear_button.clicked.connect (clear_button_clicked);

			header_start_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			header_start_box.append (back_button);
			header_start_box.append (clear_button);

			advanced_label = new Gtk.Label (_("Advanced"));
			advanced_label.set_xalign (0);

			advanced_switch = new Gtk.Switch ();
			advanced_switch.set_valign (Gtk.Align.CENTER);

			advanced_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			advanced_box.set_valign (Gtk.Align.CENTER);
			advanced_box.append (advanced_label);
			advanced_box.append (advanced_switch);

			apply_button = new Gtk.Button.with_label(_("Apply"));
			apply_button.set_tooltip_text(_("Apply the current modifications"));
			apply_button.clicked.connect(apply_button_clicked);

			actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			actions_box.append (advanced_box);
			actions_box.append (apply_button);

			page_header = new Gtk.CenterBox ();
			page_header.set_hexpand (true);
			page_header.set_start_widget (header_start_box);
			page_header.set_center_widget (title_box);
			page_header.set_end_widget (actions_box);

			header_clamp = new Adw.Clamp ();
			header_clamp.set_maximum_size (1180);
			header_clamp.set_margin_start (18);
			header_clamp.set_margin_end (18);
			header_clamp.set_margin_top (10);
			header_clamp.set_child (page_header);

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
			launch_options_group.add(modify_launch_options_row);

			warning_label = new Gtk.Label(_("Enable all the options that you want the mass edit to take into account."));
			warning_label.add_css_class("warning");

			content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 18);
			content_box.append(compatibility_tool_group);
			content_box.append(launch_options_group);
			content_box.append(launch_options_editor);

			content_box.append(warning_label);

			scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.set_hexpand (true);
			scrolled_window.set_vexpand (true);

			content_clamp = new Adw.Clamp ();
			content_clamp.set_maximum_size (1180);
			content_clamp.set_margin_start (18);
			content_clamp.set_margin_end (18);
			content_clamp.set_margin_top (10);
			content_clamp.set_margin_bottom (10);
			content_clamp.set_child (content_box);

			scrolled_window.set_child (content_clamp);

			append (header_clamp);
			append (scrolled_window);
		}

		public void load (GameRow[] rows, ListStore model, Gtk.PropertyExpression expression) {
			this.rows = rows;

			subtitle_label.set_label (rows.length == 1 ? _("1 game selected") : _("%u games selected").printf(rows.length));

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
