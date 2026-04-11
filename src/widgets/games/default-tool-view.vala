namespace ProtonPlus.Widgets {
	class DefaultCompatibilityToolField : Gtk.Box {
		public Gtk.DropDown dropdown { get; private set; }

		public DefaultCompatibilityToolField (ListStore model, Gtk.PropertyExpression expression) {
			Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

			add_css_class ("card");

			var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
			content_box.set_margin_start (14);
			content_box.set_margin_end (14);
			content_box.set_margin_top (14);
			content_box.set_margin_bottom (14);

			var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
			header_box.set_hexpand (true);

			var labels_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
			labels_box.set_hexpand (true);

			var title_label = new Gtk.Label (_("Compatibility tool"));
			title_label.set_xalign (0);

			var subtitle_label = new Gtk.Label (_("Choose the default compatibility tool Steam should use for games without an explicit override."));
			subtitle_label.set_xalign (0);
			subtitle_label.set_wrap (true);
			subtitle_label.add_css_class ("dim-label");

			var controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			controls_box.set_hexpand (false);
			controls_box.set_valign (Gtk.Align.START);
			controls_box.set_halign (Gtk.Align.END);

			dropdown = new Gtk.DropDown (model, expression);
			dropdown.set_size_request (260, -1);
			dropdown.set_hexpand (false);
			dropdown.set_valign (Gtk.Align.START);
			dropdown.set_halign (Gtk.Align.END);

			labels_box.append (title_label);
			labels_box.append (subtitle_label);

			controls_box.append (dropdown);

			header_box.append (labels_box);
			header_box.append (controls_box);

			content_box.append (header_box);
			append (content_box);
		}
	}

	public class DefaultToolView : Gtk.Box {
		public signal void back_requested ();

		Gtk.CenterBox page_header { get; set; }
		Adw.Clamp header_clamp { get; set; }
		Adw.Clamp content_clamp { get; set; }
		Gtk.Box title_box { get; set; }
		Gtk.Box header_start_box { get; set; }
		Gtk.Box actions_box { get; set; }
		Gtk.Label title_label { get; set; }
		Gtk.Label subtitle_label { get; set; }
		Gtk.Button back_button { get; set; }
		Gtk.Button clear_button { get; set; }
		Gtk.Button apply_button { get; set; }
		Gtk.ScrolledWindow scrolled_window { get; set; }
		Gtk.Box content_box { get; set; }
		DefaultCompatibilityToolField compatibility_tool_field { get; set; }
		Models.Launchers.Steam launcher { get; set; }
		uint applied_selected_index { get; set; }
		bool applied_verified { get; set; }

		construct {
			set_orientation (Gtk.Orientation.VERTICAL);
			set_hexpand (true);
			set_vexpand (true);
			set_spacing (10);

			title_label = new Gtk.Label (_("Set the default compatibility tool"));
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
			clear_button.set_tooltip_text (_("Reset to the current default compatibility tool"));
			clear_button.clicked.connect (clear_button_clicked);

			header_start_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			header_start_box.append (back_button);
			header_start_box.append (clear_button);

			apply_button = new Gtk.Button.with_label (_("Apply"));
			apply_button.set_tooltip_text (_("Apply the current modification"));
			apply_button.clicked.connect (apply_button_clicked);

			actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			actions_box.append (apply_button);

			page_header = new Gtk.CenterBox ();
			page_header.set_hexpand (true);
			page_header.set_start_widget (header_start_box);
			page_header.set_center_widget (title_box);
			page_header.set_end_widget (actions_box);

			header_clamp = new Adw.Clamp ();
			header_clamp.set_maximum_size (1180);
			header_clamp.set_tightening_threshold (1180);
			header_clamp.set_margin_start (18);
			header_clamp.set_margin_end (18);
			header_clamp.set_margin_top (10);
			header_clamp.set_child (page_header);

			content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);

			content_clamp = new Adw.Clamp ();
			content_clamp.set_maximum_size (1180);
			content_clamp.set_tightening_threshold (1180);
			content_clamp.set_margin_start (18);
			content_clamp.set_margin_end (18);
			content_clamp.set_margin_top (10);
			content_clamp.set_margin_bottom (10);
			content_clamp.set_child (content_box);

			scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.set_hexpand (true);
			scrolled_window.set_vexpand (true);
			scrolled_window.set_child (content_clamp);

			append (header_clamp);
			append (scrolled_window);
		}

		public void load (Models.Launchers.Steam launcher) {
			this.launcher = launcher;

			subtitle_label.set_label (launcher.title);
			subtitle_label.set_visible (launcher.title != "");

			if (compatibility_tool_field != null)
				content_box.remove (compatibility_tool_field);

			var model = new ListStore (typeof (Models.SimpleRunner));
			foreach (var compatibility_tool in launcher.compatibility_tools) {
				model.append (compatibility_tool);
			}

			var expression = new Gtk.PropertyExpression (typeof (Models.SimpleRunner), null, "display_title");

			compatibility_tool_field = new DefaultCompatibilityToolField (model, expression);
			compatibility_tool_field.dropdown.notify["selected"].connect (compatibility_tool_selection_changed);
			content_box.append (compatibility_tool_field);

			select_current_default_tool ();

			applied_selected_index = compatibility_tool_field.dropdown.get_selected ();
			applied_verified = false;
			refresh_apply_button ();
		}

		void compatibility_tool_selection_changed () {
			refresh_apply_button ();
		}

		void select_current_default_tool () {
			for (var i = 0; i < launcher.compatibility_tools.size; i++) {
				if (launcher.compatibility_tools[i].internal_title == launcher.default_compatibility_tool) {
					compatibility_tool_field.dropdown.set_selected ((uint) i);
					return;
				}
			}

			compatibility_tool_field.dropdown.set_selected (0);
		}

		void clear_button_clicked () {
			if (compatibility_tool_field == null)
				return;

			compatibility_tool_field.dropdown.set_selected (applied_selected_index);
			refresh_apply_button ();
		}

		void apply_button_clicked () {
			if (launcher == null || compatibility_tool_field == null)
				return;

			var item = compatibility_tool_field.dropdown.get_selected_item () as Models.SimpleRunner;
			if (item == null)
				return;

			var success = launcher.change_default_compatibility_tool (item.internal_title);
			if (!success) {
				var dialog = new ErrorDialog (_("Couldn't change the default compatibility tool"), _("Please report this issue on GitHub."));
				dialog.present (Application.window);

				return;
			}

			applied_selected_index = compatibility_tool_field.dropdown.get_selected ();
			applied_verified = true;
			refresh_apply_button ();
		}

		void refresh_apply_button () {
			var has_changes = compatibility_tool_field != null && compatibility_tool_field.dropdown.get_selected () != applied_selected_index;

			clear_button.set_sensitive (has_changes);
			apply_button.set_sensitive (has_changes);

			if (!has_changes && applied_verified) {
				apply_button.set_label (_("Applied"));
				apply_button.set_tooltip_text (_("The default compatibility tool has been written to disk."));
			} else {
				apply_button.set_label (_("Apply"));
				apply_button.set_tooltip_text (_("Apply the current modification"));
			}
		}
	}
}
