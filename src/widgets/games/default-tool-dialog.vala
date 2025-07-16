namespace ProtonPlus.Widgets {
	public class DefaultToolDialog : Adw.Dialog {
		Adw.HeaderBar header_bar { get; set; }
		Adw.ToolbarView toolbar_view { get; set; }
		Adw.WindowTitle window_title { get; set; }
		Gtk.Button apply_button { get; set; }
		Adw.ComboRow compatibility_tool_row { get; set; }
		Adw.PreferencesGroup compatibility_tool_group { get; set; }
		Models.Launchers.Steam launcher { get; set; }

		public DefaultToolDialog(Models.Launchers.Steam launcher) {
			this.launcher = launcher;

			window_title = new Adw.WindowTitle(_("Set the default compatibility tool"), "");

			apply_button = new Gtk.Button.with_label(_("Apply"));
			apply_button.set_tooltip_text(_("Apply the current modification"));
			apply_button.clicked.connect(apply_button_clicked);

			header_bar = new Adw.HeaderBar();
			header_bar.pack_start(apply_button);
			header_bar.set_title_widget(window_title);

			var model = new ListStore(typeof (Models.SimpleRunner));
			foreach (var ct in launcher.compatibility_tools)
				model.append(ct);

			var expression = new Gtk.PropertyExpression(typeof (Models.SimpleRunner), null, "display_title");

			compatibility_tool_row = new CompatibilityToolRow(model, expression);

			for (var i = 0; i < launcher.compatibility_tools.length(); i++) {
				if (launcher.compatibility_tools.nth_data(i).internal_title == launcher.default_compatibility_tool) {
					compatibility_tool_row.set_selected(i);
					break;
				}
			}

			compatibility_tool_group = new Adw.PreferencesGroup();
			compatibility_tool_group.add(compatibility_tool_row);
			compatibility_tool_group.set_margin_start(10);
			compatibility_tool_group.set_margin_end(10);
			compatibility_tool_group.set_margin_top(10);
			compatibility_tool_group.set_margin_bottom(10);

			toolbar_view = new Adw.ToolbarView();
			toolbar_view.add_top_bar(header_bar);
			toolbar_view.set_content(compatibility_tool_group);

			set_size_request(750, 0);
			set_child(toolbar_view);

		}

		void apply_button_clicked() {
			var item = (Models.SimpleRunner) compatibility_tool_row.get_selected_item();

			var success = launcher.change_default_compatibility_tool(item.internal_title);
			if (!success) {
				var dialog = new Adw.AlertDialog(_("Error"), "%s\n\n%s".printf(_("When trying to change the default compatibility tool an error occurred."), _("Please report this issue on GitHub.")));
				dialog.add_response("ok", _("OK"));
				dialog.present(Application.window);
			}

			close();
		}
	}
}
