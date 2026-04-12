namespace ProtonPlus.Widgets {
	public class DefaultToolView : Gtk.Box {
		public signal void back_requested ();

		Adw.WindowTitle window_title { get; set; }
		Gtk.Button back_button { get; set; }
		Gtk.Button clear_button { get; set; }
		Gtk.Button apply_button { get; set; }
		Adw.HeaderBar header_bar { get; set; }
		Adw.ToolbarView toolbar_view { get; set; }
		Adw.PreferencesGroup content_group { get; set; }
		CompatibilityToolRow compatibility_tool_row { get; set; }
		Models.Launchers.Steam launcher { get; set; }
		uint applied_selected_index { get; set; }
		bool applied_verified { get; set; }

		construct {
			set_orientation (Gtk.Orientation.VERTICAL);

			window_title = new Adw.WindowTitle (_("Set the default compatibility tool"), "");

			back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic");
			back_button.add_css_class ("flat");
			back_button.set_tooltip_text (_("Back"));
			back_button.clicked.connect (() => back_requested ());

			clear_button = new Gtk.Button.from_icon_name ("eraser-symbolic");
			clear_button.add_css_class ("flat");
			clear_button.add_css_class ("clear-button");
			clear_button.set_tooltip_text (_("Reset to the current default compatibility tool"));
			clear_button.clicked.connect (clear_button_clicked);

			apply_button = new Gtk.Button.from_icon_name ("floppy-disk-symbolic");
			apply_button.add_css_class ("flat");
			apply_button.add_css_class ("apply-button");
			apply_button.set_tooltip_text (_("Apply the current modification"));
			apply_button.clicked.connect (apply_button_clicked);

			header_bar = new Adw.HeaderBar ();
			header_bar.set_title_widget (window_title);
			header_bar.pack_start (back_button);
			header_bar.pack_start (clear_button);
			header_bar.pack_end (apply_button);

			content_group = new Adw.PreferencesGroup ();
			content_group.set_margin_top (7);

			var content_clamp = new Adw.Clamp ();
			content_clamp.set_maximum_size (975);
			content_clamp.set_child (content_group);

			toolbar_view = new Adw.ToolbarView ();
			toolbar_view.add_top_bar (header_bar);
			toolbar_view.set_content (content_clamp);

			append (toolbar_view);
		}

		public void load (Models.Launchers.Steam launcher) {
			this.launcher = launcher;

			if (compatibility_tool_row != null)
				content_group.remove (compatibility_tool_row);

			var model = new ListStore (typeof (Models.SimpleRunner));
			foreach (var compatibility_tool in launcher.compatibility_tools) {
				model.append (compatibility_tool);
			}

			var expression = new Gtk.PropertyExpression (typeof (Models.SimpleRunner), null, "display_title");

			compatibility_tool_row = new CompatibilityToolRow (model, expression);
			compatibility_tool_row.title = _("Compatibility tool");
			compatibility_tool_row.subtitle = _("Choose the default compatibility tool Steam should use for games without an explicit override.");
			compatibility_tool_row.notify["selected"].connect (compatibility_tool_selection_changed);
			content_group.add (compatibility_tool_row);

			select_current_default_tool ();

			applied_selected_index = compatibility_tool_row.get_selected ();
			applied_verified = false;
			refresh_apply_button ();
		}

		void compatibility_tool_selection_changed () {
			refresh_apply_button ();
		}

		void select_current_default_tool () {
			for (var i = 0; i < launcher.compatibility_tools.size; i++) {
				if (launcher.compatibility_tools[i].internal_title == launcher.default_compatibility_tool) {
					compatibility_tool_row.set_selected ((uint) i);
					return;
				}
			}

			compatibility_tool_row.set_selected (0);
		}

		void clear_button_clicked () {
			if (compatibility_tool_row == null)
				return;

			compatibility_tool_row.set_selected (applied_selected_index);
			refresh_apply_button ();
		}

		void apply_button_clicked () {
			if (launcher == null || compatibility_tool_row == null)
				return;

			var item = compatibility_tool_row.get_selected_item () as Models.SimpleRunner;
			if (item == null)
				return;

			var success = launcher.change_default_compatibility_tool (item.internal_title);
			if (!success) {
				var dialog = new ErrorDialog (_("Couldn't change the default compatibility tool"), _("Please report this issue on GitHub."));
				dialog.present (Application.window);

				return;
			}

			applied_selected_index = compatibility_tool_row.get_selected ();
			applied_verified = true;
			refresh_apply_button ();
		}

		void refresh_apply_button () {
			var has_changes = compatibility_tool_row != null && compatibility_tool_row.get_selected () != applied_selected_index;

			clear_button.set_sensitive (has_changes);
			apply_button.set_sensitive (has_changes);
		}
	}
}
