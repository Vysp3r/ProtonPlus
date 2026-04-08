namespace ProtonPlus.Widgets {
	public class LaunchOptionsView : Gtk.Box {
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
		LaunchOptionsEditor launch_options_editor { get; set; }
		GameRow row { get; set; }
		string applied_launch_options { get; set; }
		bool applied_verified { get; set; }

		construct {
			set_orientation (Gtk.Orientation.VERTICAL);
			set_hexpand (true);
			set_vexpand (true);
			set_spacing (10);

			title_label = new Gtk.Label (_("Modify launch options"));
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
			clear_button.set_tooltip_text (_("Clear the current launch options"));
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

			apply_button = new Gtk.Button.with_label (_("Apply"));
			apply_button.set_tooltip_text (_("Apply the current modification"));
			apply_button.clicked.connect (apply_button_clicked);

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

			launch_options_editor = new LaunchOptionsEditor ();
			launch_options_editor.content_changed.connect (launch_options_editor_content_changed);
			advanced_switch.notify["active"].connect (() => launch_options_editor.set_advanced_visible (advanced_switch.get_active ()));

			content_clamp = new Adw.Clamp ();
			content_clamp.set_maximum_size (1180);
			content_clamp.set_margin_start (18);
			content_clamp.set_margin_end (18);
			content_clamp.set_margin_top (10);
			content_clamp.set_margin_bottom (10);
			content_clamp.set_child (launch_options_editor);

			scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.set_hexpand (true);
			scrolled_window.set_vexpand (true);
			scrolled_window.set_child (content_clamp);

			append (header_clamp);
			append (scrolled_window);
		}

		public void load (GameRow row) {
			this.row = row;

			subtitle_label.set_label (row.game.name);

			var steam_game = (Models.Games.Steam) row.game;

			applied_verified = false;
			applied_launch_options = steam_game.launch_options;
			launch_options_editor.set_text (steam_game.launch_options);
			advanced_switch.set_active (launch_options_editor.get_advanced_visible ());
			refresh_apply_button ();
		}

		void apply_button_clicked () {
			var steam_game = (Models.Games.Steam) row.game;
			var steam_launcher = (Models.Launchers.Steam) steam_game.launcher;

			var current_launch_options = launch_options_editor.get_text ();
			var success = steam_game.change_launch_options (current_launch_options, steam_launcher.profile.localconfig_path);
			if (!success) {
				var dialog = new ErrorDialog (_("Couldn't change the launch options of %s").printf (row.game.name), _("Please report this issue on GitHub."));
				dialog.present (Application.window);

				return;
			}

			applied_launch_options = current_launch_options;
			applied_verified = true;
			refresh_apply_button ();
		}

		void launch_options_editor_content_changed () {
			refresh_apply_button ();
		}

		void clear_button_clicked () {
			launch_options_editor.clear ();
			advanced_switch.set_active (launch_options_editor.get_advanced_visible ());
			refresh_apply_button ();
		}

		void refresh_apply_button () {
			var has_changes = launch_options_editor.get_text () != applied_launch_options;

			clear_button.set_sensitive (launch_options_editor.has_clearable_state ());
			apply_button.set_sensitive (has_changes);

			if (!has_changes && applied_verified) {
				apply_button.set_label (_("Applied"));
				apply_button.set_tooltip_text (_("The launch options have been written to disk."));
			} else {
				apply_button.set_label (_("Apply"));
				apply_button.set_tooltip_text (_("Apply the current modification"));
			}
		}
	}
}
