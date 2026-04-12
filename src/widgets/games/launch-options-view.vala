namespace ProtonPlus.Widgets {
	public class LaunchOptionsView : Gtk.Box {
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
		LaunchOptionsEditor launch_options_editor { get; set; }
		Adw.ToolbarView toolbar_view { get; set; }
		GameRow row { get; set; }
		string applied_launch_options { get; set; }

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
			apply_button.set_tooltip_text (_("Apply the current modification"));
			apply_button.clicked.connect (apply_button_clicked);

			header_bar = new Adw.HeaderBar ();
			header_bar.set_title_widget (window_title);
			header_bar.pack_start (back_button);
			header_bar.pack_start (clear_button);
			header_bar.pack_end (apply_button);
			header_bar.pack_end (advanced_box);

			launch_options_editor = new LaunchOptionsEditor ();
			launch_options_editor.content_changed.connect (launch_options_editor_content_changed);
			advanced_switch.notify["active"].connect (() => launch_options_editor.set_advanced_visible (advanced_switch.get_active ()));

			content_clamp = new Adw.Clamp ();
			content_clamp.set_maximum_size (975);
			content_clamp.set_child (launch_options_editor);

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

		public void load (GameRow row) {
			this.row = row;

			window_title.set_subtitle (row.game.name);

			var steam_game = (Models.Games.Steam) row.game;

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
		}
	}
}
