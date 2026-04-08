namespace ProtonPlus.Widgets {
	enum WrapperMode {
		NONE,
		GAMESCOPE,
		SCOPEBUDDY
	}

	class LaunchOptionBinding : Object {
		public string[] tokens { get; set; }
		public Gtk.Switch toggle { get; set; }

		public LaunchOptionBinding (string[] tokens, Gtk.Switch toggle) {
			this.tokens = tokens;
			this.toggle = toggle;
		}
	}

	class LaunchOptionTile : Gtk.Box {
		public Gtk.Switch toggle { get; private set; }

		public LaunchOptionTile (string title, string subtitle) {
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

			var title_label = new Gtk.Label (title);
			title_label.set_xalign (0);

			var subtitle_label = new Gtk.Label (subtitle);
			subtitle_label.set_xalign (0);
			subtitle_label.set_wrap (true);
			subtitle_label.add_css_class ("dim-label");

			toggle = new Gtk.Switch ();
			toggle.set_valign (Gtk.Align.START);
			toggle.set_halign (Gtk.Align.END);

			labels_box.append (title_label);
			labels_box.append (subtitle_label);

			header_box.append (labels_box);
			header_box.append (toggle);

			content_box.append (header_box);
			append (content_box);
		}
	}

	class LaunchOptionSpinTile : Gtk.Box {
		public Gtk.Switch toggle { get; private set; }
		public Gtk.Entry value_entry { get; private set; }
		public Gtk.Button apply_button { get; private set; }
		Gtk.Box spacer_box;
		Gtk.Box value_box;
		public signal void value_applied ();
		int lower_value;
		int upper_value;
		int committed_value;

		public LaunchOptionSpinTile (string title, string subtitle, string value_label, double lower, double upper, int default_value) {
			Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

			add_css_class ("card");
			lower_value = (int) lower;
			upper_value = (int) upper;
			committed_value = default_value;

			var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
			content_box.set_margin_start (14);
			content_box.set_margin_end (14);
			content_box.set_margin_top (14);
			content_box.set_margin_bottom (14);

			var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
			header_box.set_hexpand (true);

			var labels_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
			labels_box.set_hexpand (true);

			var title_label = new Gtk.Label (title);
			title_label.set_xalign (0);

			var subtitle_label = new Gtk.Label (subtitle);
			subtitle_label.set_xalign (0);
			subtitle_label.set_wrap (true);
			subtitle_label.add_css_class ("dim-label");

			toggle = new Gtk.Switch ();
			toggle.set_valign (Gtk.Align.START);
			toggle.set_halign (Gtk.Align.END);

			labels_box.append (title_label);
			labels_box.append (subtitle_label);

			var controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			controls_box.set_size_request (190, -1);
			controls_box.set_halign (Gtk.Align.END);
			controls_box.set_valign (Gtk.Align.START);

			spacer_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
			spacer_box.set_hexpand (true);

			value_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			value_box.set_valign (Gtk.Align.START);

			var value_caption = new Gtk.Label (value_label);
			value_caption.set_xalign (0);
			value_caption.add_css_class ("dim-label");

			value_entry = new Gtk.Entry ();
			value_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
			value_entry.set_width_chars (5);
			value_entry.set_max_width_chars (5);
			value_entry.set_halign (Gtk.Align.START);
			value_entry.set_text (default_value.to_string ());
			value_entry.activate.connect (apply_pending_value);

			apply_button = new Gtk.Button.with_label (_("Set"));
			apply_button.set_tooltip_text (_("Apply the FPS value"));
			apply_button.clicked.connect (apply_pending_value);

			value_box.append (value_caption);
			value_box.append (value_entry);
			value_box.append (apply_button);

			controls_box.append (spacer_box);
			controls_box.append (value_box);
			controls_box.append (toggle);

			header_box.append (labels_box);
			header_box.append (controls_box);

			content_box.append (header_box);

			append (content_box);

			value_entry.changed.connect (refresh_value_state);
			toggle.notify["active"].connect (refresh_value_state);
			refresh_value_state ();
		}

		public int get_value_as_int () {
			return committed_value;
		}

		public void set_value (int value) {
			committed_value = int.max (lower_value, int.min (upper_value, value));
			value_entry.set_text (committed_value.to_string ());
			refresh_value_state ();
		}

		void apply_pending_value () {
			int pending_value;
			if (!get_pending_value (out pending_value))
				return;

			committed_value = pending_value;
			value_entry.set_text (committed_value.to_string ());
			refresh_value_state ();
			value_applied ();
		}

		bool get_pending_value (out int value) {
			value = committed_value;

			var text = value_entry.get_text ().strip ();
			if (text == "")
				return false;

			int parsed_value;
			if (!int.try_parse (text, out parsed_value))
				return false;

			if (parsed_value < lower_value || parsed_value > upper_value)
				return false;

			value = parsed_value;
			return true;
		}

		void refresh_value_state () {
			var is_active = toggle.get_active ();
			value_box.set_visible (is_active);
			value_entry.set_sensitive (is_active);

			int pending_value;
			var has_pending_value = get_pending_value (out pending_value);
			apply_button.set_sensitive (is_active && has_pending_value && pending_value != committed_value);
		}
	}

	class LaunchOptionEntryField : Gtk.Box {
		public Gtk.Entry entry { get; private set; }
		public Gtk.Button apply_button { get; private set; }
		public signal void value_applied ();
		string committed_text;

		public LaunchOptionEntryField (string title, string subtitle, string placeholder) {
			Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

			add_css_class ("card");
			committed_text = "";

			var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
			content_box.set_margin_start (14);
			content_box.set_margin_end (14);
			content_box.set_margin_top (14);
			content_box.set_margin_bottom (14);

			var title_label = new Gtk.Label (title);
			title_label.set_xalign (0);

			var subtitle_label = new Gtk.Label (subtitle);
			subtitle_label.set_xalign (0);
			subtitle_label.set_wrap (true);
			subtitle_label.add_css_class ("dim-label");
			subtitle_label.set_visible (subtitle != "");

			entry = new Gtk.Entry ();
			entry.set_placeholder_text (placeholder);
			entry.set_hexpand (true);
			entry.activate.connect (apply_pending_text);

			apply_button = new Gtk.Button.with_label (_("Set"));
			apply_button.set_tooltip_text (_("Apply the current value"));
			apply_button.clicked.connect (apply_pending_text);

			var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			input_box.append (entry);
			input_box.append (apply_button);

			content_box.append (title_label);
			content_box.append (subtitle_label);
			content_box.append (input_box);

			append (content_box);

			entry.changed.connect (refresh_apply_state);
			refresh_apply_state ();
		}

		public string get_text () {
			return committed_text;
		}

		public void focus_entry () {
			entry.grab_focus ();
		}

		public void set_text (string text) {
			committed_text = text.strip ();
			entry.set_text (committed_text);
			refresh_apply_state ();
		}

		void apply_pending_text () {
			var pending_text = entry.get_text ().strip ();
			if (pending_text == committed_text)
				return;

			committed_text = pending_text;
			entry.set_text (committed_text);
			refresh_apply_state ();
			value_applied ();
		}

		void refresh_apply_state () {
			apply_button.set_sensitive (entry.get_text ().strip () != committed_text);
		}
	}

	class LaunchOptionResolutionChoice : Object {
		public string label { get; set; }
		public int width { get; set; }
		public int height { get; set; }
		public bool is_auto { get; set; }
		public bool is_custom { get; set; }

		public LaunchOptionResolutionChoice (string label, int width = 0, int height = 0, bool is_auto = false, bool is_custom = false) {
			this.label = label;
			this.width = width;
			this.height = height;
			this.is_auto = is_auto;
			this.is_custom = is_custom;
		}
	}

	class LaunchOptionResolutionField : Gtk.Box {
		public Gtk.Switch toggle { get; private set; }
		public Gtk.DropDown dropdown { get; private set; }
		Gtk.Box top_controls_box;
		Gtk.Box controls_spacer_box;
		Gtk.Box options_box;
		public Gtk.Box custom_box { get; private set; }
		public Gtk.Entry width_entry { get; private set; }
		public Gtk.Entry height_entry { get; private set; }
		public Gtk.Button apply_button { get; private set; }
		public signal void value_applied ();
		Gee.ArrayList<LaunchOptionResolutionChoice> choices;
		int committed_width;
		int committed_height;

		public LaunchOptionResolutionField (string title, string subtitle, bool include_auto = false) {
			Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

			add_css_class ("card");
			committed_width = 1920;
			committed_height = 1080;

			choices = new Gee.ArrayList<LaunchOptionResolutionChoice> ();
			choices.add (new LaunchOptionResolutionChoice (_("Default")));
			if (include_auto)
				choices.add (new LaunchOptionResolutionChoice (_("Auto detect"), 0, 0, true));
			choices.add (new LaunchOptionResolutionChoice ("1280 x 720", 1280, 720));
			choices.add (new LaunchOptionResolutionChoice ("1600 x 900", 1600, 900));
			choices.add (new LaunchOptionResolutionChoice ("1920 x 1080", 1920, 1080));
			choices.add (new LaunchOptionResolutionChoice ("2560 x 1440", 2560, 1440));
			choices.add (new LaunchOptionResolutionChoice ("3840 x 2160", 3840, 2160));
			choices.add (new LaunchOptionResolutionChoice (_("Custom"), 0, 0, false, true));

			var labels = new string[choices.size];
			for (var index = 0; index < choices.size; index++) {
				labels[index] = choices[index].label;
			}

			var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
			content_box.set_margin_start (14);
			content_box.set_margin_end (14);
			content_box.set_margin_top (14);
			content_box.set_margin_bottom (14);

			var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
			header_box.set_hexpand (true);

			var labels_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
			labels_box.set_hexpand (true);

			var title_label = new Gtk.Label (title);
			title_label.set_xalign (0);

			var subtitle_label = new Gtk.Label (subtitle);
			subtitle_label.set_xalign (0);
			subtitle_label.set_wrap (true);
			subtitle_label.add_css_class ("dim-label");

			var controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			controls_box.set_size_request (260, -1);
			controls_box.set_hexpand (false);
			controls_box.set_valign (Gtk.Align.START);

			toggle = new Gtk.Switch ();
			toggle.set_valign (Gtk.Align.START);
			toggle.set_halign (Gtk.Align.END);

			var expression = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");
			dropdown = new Gtk.DropDown (new Gtk.StringList (labels), expression);
			dropdown.set_size_request (140, -1);
			dropdown.set_valign (Gtk.Align.START);
			dropdown.set_hexpand (false);

			custom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			custom_box.set_halign (Gtk.Align.END);
			custom_box.set_valign (Gtk.Align.START);

			width_entry = new Gtk.Entry ();
			width_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
			width_entry.set_width_chars (4);
			width_entry.set_max_width_chars (4);
			width_entry.set_text (committed_width.to_string ());
			width_entry.activate.connect (apply_pending_resolution);

			var separator_label = new Gtk.Label ("x");
			separator_label.add_css_class ("dim-label");

			height_entry = new Gtk.Entry ();
			height_entry.set_input_purpose (Gtk.InputPurpose.DIGITS);
			height_entry.set_width_chars (4);
			height_entry.set_max_width_chars (4);
			height_entry.set_text (committed_height.to_string ());
			height_entry.activate.connect (apply_pending_resolution);

			apply_button = new Gtk.Button.with_label (_("Set"));
			apply_button.set_tooltip_text (_("Apply the custom resolution"));
			apply_button.clicked.connect (apply_pending_resolution);

			custom_box.append (width_entry);
			custom_box.append (separator_label);
			custom_box.append (height_entry);
			custom_box.append (apply_button);

			options_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
			options_box.set_valign (Gtk.Align.START);
			top_controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
			top_controls_box.set_hexpand (true);

			controls_spacer_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
			controls_spacer_box.set_hexpand (true);

			top_controls_box.append (controls_spacer_box);
			top_controls_box.append (dropdown);
			top_controls_box.append (toggle);

			options_box.append (top_controls_box);
			options_box.append (custom_box);
			controls_box.append (options_box);

			labels_box.append (title_label);
			labels_box.append (subtitle_label);

			header_box.append (labels_box);
			header_box.append (controls_box);

			content_box.append (header_box);

			append (content_box);

			toggle.notify["active"].connect (refresh_options_visibility);
			dropdown.notify["selected"].connect (refresh_custom_visibility);
			width_entry.changed.connect (refresh_custom_state);
			height_entry.changed.connect (refresh_custom_state);
			refresh_options_visibility ();
		}

		public void reset () {
			toggle.set_active (false);
			dropdown.set_selected (0);
			committed_width = 1920;
			committed_height = 1080;
			width_entry.set_text (committed_width.to_string ());
			height_entry.set_text (committed_height.to_string ());
			refresh_options_visibility ();
		}

		public void set_auto () {
			for (var index = 0; index < choices.size; index++) {
				if (choices[index].is_auto) {
					toggle.set_active (true);
					dropdown.set_selected ((uint) index);
					refresh_options_visibility ();
					return;
				}
			}
		}

		public void set_resolution (int width, int height) {
			for (var index = 0; index < choices.size; index++) {
				if (choices[index].width == width && choices[index].height == height && !choices[index].is_custom) {
					toggle.set_active (true);
					dropdown.set_selected ((uint) index);
					refresh_options_visibility ();
					return;
				}
			}

			for (var index = 0; index < choices.size; index++) {
				if (!choices[index].is_custom)
					continue;

				committed_width = width;
				committed_height = height;
				width_entry.set_text (committed_width.to_string ());
				height_entry.set_text (committed_height.to_string ());
				toggle.set_active (true);
				dropdown.set_selected ((uint) index);
				refresh_options_visibility ();
				return;
			}
		}

		public bool is_default () {
			if (!toggle.get_active ())
				return true;

			return get_selected_choice ().width == 0 && get_selected_choice ().height == 0 && !get_selected_choice ().is_auto && !get_selected_choice ().is_custom;
		}

		public bool is_auto () {
			return toggle.get_active () && get_selected_choice ().is_auto;
		}

		public bool has_resolution () {
			if (!toggle.get_active ())
				return false;

			return get_selected_choice ().is_custom || get_selected_choice ().width > 0 || get_selected_choice ().height > 0;
		}

		public void get_resolution (out int width, out int height) {
			var selected_choice = get_selected_choice ();
			if (selected_choice.is_custom) {
				width = committed_width;
				height = committed_height;
			} else {
				width = selected_choice.width;
				height = selected_choice.height;
			}
		}

		LaunchOptionResolutionChoice get_selected_choice () {
			return choices[(int) dropdown.get_selected ()];
		}

		void refresh_options_visibility () {
			var is_active = toggle.get_active ();
			dropdown.set_visible (is_active);
			dropdown.set_sensitive (is_active);
			refresh_custom_visibility ();
		}

		void refresh_custom_visibility () {
			custom_box.set_visible (toggle.get_active () && get_selected_choice ().is_custom);
			refresh_custom_state ();
		}

		void apply_pending_resolution () {
			int pending_width;
			int pending_height;
			if (!get_pending_resolution (out pending_width, out pending_height))
				return;

			committed_width = pending_width;
			committed_height = pending_height;
			width_entry.set_text (committed_width.to_string ());
			height_entry.set_text (committed_height.to_string ());
			refresh_custom_state ();
			value_applied ();
		}

		bool get_pending_resolution (out int width, out int height) {
			width = committed_width;
			height = committed_height;

			var width_text = width_entry.get_text ().strip ();
			var height_text = height_entry.get_text ().strip ();
			if (width_text == "" || height_text == "")
				return false;

			if (!int.try_parse (width_text, out width) || !int.try_parse (height_text, out height))
				return false;

			return width >= 320 && width <= 7680 && height >= 240 && height <= 4320;
		}

		void refresh_custom_state () {
			var is_custom = toggle.get_active () && get_selected_choice ().is_custom;
			width_entry.set_sensitive (is_custom);
			height_entry.set_sensitive (is_custom);

			int pending_width;
			int pending_height;
			var has_pending_resolution = get_pending_resolution (out pending_width, out pending_height);
			apply_button.set_sensitive (is_custom && has_pending_resolution && (pending_width != committed_width || pending_height != committed_height));
		}
	}

	class LaunchOptionPreviewField : Gtk.Box {
		public Gtk.Label preview_label { get; private set; }

		public LaunchOptionPreviewField (string title) {
			Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

			add_css_class ("card");

			var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
			content_box.set_margin_start (14);
			content_box.set_margin_end (14);
			content_box.set_margin_top (10);
			content_box.set_margin_bottom (10);

			var title_label = new Gtk.Label (title);
			title_label.set_xalign (0);

			preview_label = new Gtk.Label ("");
			preview_label.set_xalign (0);
			preview_label.set_yalign (0);
			preview_label.set_use_markup (true);
			preview_label.set_selectable (true);
			preview_label.set_wrap (false);

			var scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
			scrolled_window.set_min_content_height (56);
			scrolled_window.set_child (preview_label);

			content_box.append (title_label);
			content_box.append (scrolled_window);

			append (content_box);
		}
	}

	public class LaunchOptionsEditor : Gtk.Box {
		public signal void content_changed ();

		Gtk.Grid common_options_grid { get; set; }
		Gtk.Grid more_options_grid { get; set; }
		Gtk.Revealer preview_revealer { get; set; }
		Gtk.Revealer gamescope_advanced_revealer { get; set; }
		Gtk.Revealer scopebuddy_advanced_revealer { get; set; }
		Gtk.Revealer more_options_revealer { get; set; }
		Gtk.Revealer advanced_options_revealer { get; set; }
		LaunchOptionTile mangohud_tile { get; set; }
		LaunchOptionTile steam_deck_tile { get; set; }
		LaunchOptionTile hdr_tile { get; set; }
		LaunchOptionTile wayland_tile { get; set; }
		LaunchOptionTile vkbasalt_tile { get; set; }
		LaunchOptionTile wined3d_tile { get; set; }
		LaunchOptionTile nvapi_tile { get; set; }
		LaunchOptionEntryField additional_args_field { get; set; }
		LaunchOptionTile additional_args_tile { get; set; }
		Gtk.Revealer additional_args_revealer { get; set; }
		LaunchOptionTile command_tile { get; set; }
		LaunchOptionTile skip_launcher_tile { get; set; }
		LaunchOptionPreviewField preview_field { get; set; }
		Gtk.Stack wrapper_stack { get; set; }
		Gtk.Revealer wrapper_options_revealer { get; set; }
		Gtk.StackSwitcher wrapper_switcher { get; set; }
		LaunchOptionTile gamescope_fullscreen_tile { get; set; }
		LaunchOptionTile gamescope_vrr_tile { get; set; }
		LaunchOptionSpinTile gamescope_framerate_tile { get; set; }
		LaunchOptionResolutionField gamescope_resolution_field { get; set; }
		LaunchOptionEntryField gamescope_args_field { get; set; }
		LaunchOptionTile scopebuddy_auto_hdr_tile { get; set; }
		LaunchOptionTile scopebuddy_auto_vrr_tile { get; set; }
		LaunchOptionSpinTile scopebuddy_framerate_tile { get; set; }
		LaunchOptionResolutionField scopebuddy_resolution_field { get; set; }
		LaunchOptionEntryField scopebuddy_args_field { get; set; }
		List<LaunchOptionBinding> common_bindings;
		List<LaunchOptionBinding> scopebuddy_bindings;
		bool advanced_visible;
		bool refreshing_controls;
		bool can_auto_enable_command;

		construct {
			common_bindings = new List<LaunchOptionBinding> ();
			scopebuddy_bindings = new List<LaunchOptionBinding> ();
			advanced_visible = false;
			can_auto_enable_command = true;
			refreshing_controls = true;

			set_orientation (Gtk.Orientation.VERTICAL);
			set_spacing (18);

			mangohud_tile = create_common_tile (_("Performance overlay"), _("Shows an in-game overlay with FPS, CPU/GPU usage, and temps."), { "mangohud" });
			steam_deck_tile = create_common_tile (_("Disable Steam Deck Mode"), _("Disables the Steam Deck-specific profile that some games use."), { "SteamDeck=0" });
			hdr_tile = create_common_tile (_("HDR"), _("Outputs HDR colors if your display supports it."), { "PROTON_ENABLE_HDR=1" });
			wayland_tile = create_common_tile (_("Wayland"), _("Runs the game natively on Wayland instead of through XWayland."), { "PROTON_ENABLE_WAYLAND=1" });
			vkbasalt_tile = create_common_tile (_("VKBasalt"), _("Adds visual effects like sharpening and color adjustments."), { "ENABLE_VKBASALT=1" });
			wined3d_tile = create_common_tile (_("WineD3D"), _("Uses OpenGL instead of Vulkan. Only enable if you're having DXVK issues."), { "PROTON_USE_WINED3D=1" });
			nvapi_tile = create_common_tile (_("NVAPI"), _("Lets games access NVIDIA-specific features (DLSS, etc.)."), { "PROTON_ENABLE_NVAPI=1" });

			preview_field = new LaunchOptionPreviewField (_("Launch command preview"));
			preview_revealer = new Gtk.Revealer ();
			preview_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
			preview_revealer.set_child (preview_field);
			append (preview_revealer);

			common_options_grid = new Gtk.Grid ();
			common_options_grid.set_column_spacing (12);
			common_options_grid.set_row_spacing (12);
			common_options_grid.set_column_homogeneous (true);
			common_options_grid.attach (mangohud_tile, 0, 0, 1, 1);
			common_options_grid.attach (hdr_tile, 1, 0, 1, 1);
			common_options_grid.attach (steam_deck_tile, 0, 1, 1, 1);
			common_options_grid.attach (wayland_tile, 1, 1, 1, 1);

			append (create_section_header (_("Common options"), _("Quick toggles for the launch options people reach for most often.")));
			append (common_options_grid);

			wrapper_stack = new Gtk.Stack ();
			wrapper_stack.set_hhomogeneous (false);
			wrapper_stack.set_vhomogeneous (false);
			wrapper_stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
			wrapper_stack.notify["visible-child-name"].connect (wrapper_selection_changed);

			wrapper_switcher = new Gtk.StackSwitcher ();
			wrapper_switcher.set_stack (wrapper_stack);
			wrapper_switcher.set_halign (Gtk.Align.START);

			wrapper_stack.add_titled (create_wrapper_placeholder (), "none", _("None"));
			wrapper_stack.add_titled (create_gamescope_page (), "gamescope", _("Gamescope"));
			wrapper_stack.add_titled (create_scopebuddy_page (), "scopebuddy", _("ScopeBuddy"));

			wrapper_options_revealer = new Gtk.Revealer ();
			wrapper_options_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
			wrapper_options_revealer.set_child (wrapper_stack);

			append (create_section_header (_("Launch tools"), _("Choose one to configure FPS caps, resolution, and other display options.")));
			append (wrapper_switcher);
			append (wrapper_options_revealer);

			additional_args_field = new LaunchOptionEntryField (_("Additional arguments"), "", _("Add extra launch options"));
			additional_args_field.value_applied.connect (standard_control_changed);

			additional_args_tile = new LaunchOptionTile (_("Custom launch arguments"), _("Lets you add launch options ProtonPlus does not cover yet."));
			additional_args_tile.toggle.notify["active"].connect (additional_args_toggle_changed);

			command_tile = new LaunchOptionTile ("%command%", _("Appends Steam's game command."));
			command_tile.toggle.notify["active"].connect (command_toggle_changed);

			skip_launcher_tile = new LaunchOptionTile (_("Skip launcher"), _("Adds -skip-launcher after the game command."));
			skip_launcher_tile.toggle.notify["active"].connect (standard_control_changed);

			more_options_grid = new Gtk.Grid ();
			more_options_grid.set_column_spacing (12);
			more_options_grid.set_row_spacing (12);
			more_options_grid.set_column_homogeneous (true);
			more_options_grid.attach (vkbasalt_tile, 0, 0, 1, 1);
			more_options_grid.attach (wined3d_tile, 1, 0, 1, 1);
			more_options_grid.attach (nvapi_tile, 0, 1, 1, 1);
			more_options_grid.attach (skip_launcher_tile, 1, 1, 1, 1);

			additional_args_revealer = new Gtk.Revealer ();
			additional_args_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
			additional_args_revealer.set_child (additional_args_field);
			additional_args_revealer.notify["child-revealed"].connect (() => {
				if (additional_args_revealer.get_child_revealed () && additional_args_tile.toggle.get_active ())
					additional_args_field.focus_entry ();
			});

			var more_options_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
			more_options_box.append (create_section_header (_("More options"), _("Extra graphics settings and launch behaviors.")));
			more_options_box.append (more_options_grid);

			more_options_revealer = new Gtk.Revealer ();
			more_options_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
			more_options_revealer.set_child (more_options_box);
			append (more_options_revealer);

			var advanced_options_grid = new Gtk.Grid ();
			advanced_options_grid.set_column_spacing (12);
			advanced_options_grid.set_row_spacing (12);
			advanced_options_grid.set_column_homogeneous (true);
			advanced_options_grid.attach (command_tile, 0, 0, 1, 1);
			advanced_options_grid.attach (additional_args_tile, 1, 0, 1, 1);

			var advanced_options_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
			advanced_options_box.append (create_section_header (_("Advanced options"), _("Extra control over the final Steam launch command.")));
			advanced_options_box.append (advanced_options_grid);
			advanced_options_box.append (additional_args_revealer);

			advanced_options_revealer = new Gtk.Revealer ();
			advanced_options_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
			advanced_options_revealer.set_child (advanced_options_box);
			append (advanced_options_revealer);

			set_selected_wrapper_mode (WrapperMode.NONE);
			refresh_advanced_visibility ();
			refreshing_controls = false;
			refresh_preview ();
		}

		public bool get_advanced_visible () {
			return advanced_visible;
		}

		public void set_advanced_visible (bool visible) {
			advanced_visible = visible;
			refresh_advanced_visibility ();
		}

		public void clear () {
			var keep_advanced_visible = advanced_visible;
			set_text ("");
			set_advanced_visible (keep_advanced_visible);
		}

		public bool has_clearable_state () {
			foreach (var binding in common_bindings) {
				if (binding.toggle.get_active ())
					return true;
			}

			foreach (var binding in scopebuddy_bindings) {
				if (binding.toggle.get_active ())
					return true;
			}

			if (get_selected_wrapper_mode () != WrapperMode.NONE)
				return true;

			if (gamescope_fullscreen_tile.toggle.get_active ()
				|| gamescope_vrr_tile.toggle.get_active ()
				|| gamescope_framerate_tile.toggle.get_active ()
				|| gamescope_resolution_field.toggle.get_active ()
				|| gamescope_args_field.get_text () != "")
				return true;

			if (scopebuddy_framerate_tile.toggle.get_active ()
				|| scopebuddy_resolution_field.toggle.get_active ()
				|| scopebuddy_args_field.get_text () != "")
				return true;

			if (additional_args_tile.toggle.get_active ()
				|| additional_args_field.get_text () != ""
				|| command_tile.toggle.get_active ()
				|| skip_launcher_tile.toggle.get_active ())
				return true;

			return false;
		}

		public string get_text () {
			var output = new StringBuilder ();
			var command_segments = get_command_segments ();

			if (command_segments.size == 0)
				return "";

			foreach (var segment in command_segments) {
				if (output.len > 0)
					output.append (" ");

				output.append (segment);
			}

			return output.str;
		}

		public void set_text (string launch_options) {
			var tokens = get_launch_option_tokens (launch_options);
			var consumed = new bool[tokens.length];
			var selected_wrapper_mode = detect_wrapper_mode (tokens);

			refreshing_controls = true;

			reset_controls ();
			apply_bindings_from_tokens (common_bindings, tokens, consumed);

			if (selected_wrapper_mode == WrapperMode.GAMESCOPE)
				parse_gamescope_tokens (tokens, consumed);
			else if (selected_wrapper_mode == WrapperMode.SCOPEBUDDY)
				parse_scopebuddy_tokens (tokens, consumed);

			var command_index = get_token_index (tokens, "%command%");
			command_tile.toggle.set_active (command_index >= 0);
			if (command_index >= 0)
				consumed[command_index] = true;

			var skip_launcher_index = get_unconsumed_token_index (tokens, "-skip-launcher", consumed);
			skip_launcher_tile.toggle.set_active (skip_launcher_index >= 0);
			if (skip_launcher_index >= 0)
				consumed[skip_launcher_index] = true;

			set_selected_wrapper_mode (selected_wrapper_mode);
			var additional_args = join_unconsumed_tokens (tokens, consumed);
			additional_args_field.set_text (additional_args);
			additional_args_tile.toggle.set_active (additional_args != "");
			advanced_visible = should_show_advanced_controls ();
			refresh_advanced_visibility ();

			can_auto_enable_command = command_index < 0;
			refreshing_controls = false;
			refresh_preview ();
		}

		LaunchOptionTile create_common_tile (string title, string subtitle, string[] tokens) {
			var tile = new LaunchOptionTile (title, subtitle);
			tile.toggle.notify["active"].connect (standard_control_changed);

			common_bindings.append (new LaunchOptionBinding (tokens, tile.toggle));

			return tile;
		}

		Gtk.Widget create_section_header (string title, string subtitle) {
			var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);

			var title_label = new Gtk.Label (title);
			title_label.set_xalign (0);
			title_label.add_css_class ("title-4");
			box.append (title_label);

			var subtitle_label = new Gtk.Label (subtitle);
			subtitle_label.set_xalign (0);
			subtitle_label.set_wrap (true);
			subtitle_label.add_css_class ("dim-label");
			box.append (subtitle_label);

			return box;
		}

		Gtk.Widget create_wrapper_placeholder () {
			var placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			placeholder.add_css_class ("card");

			var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
			content_box.set_margin_start (18);
			content_box.set_margin_end (18);
			content_box.set_margin_top (18);
			content_box.set_margin_bottom (18);

			var title_label = new Gtk.Label (_("No launch tool selected"));
			title_label.set_xalign (0);

			var subtitle_label = new Gtk.Label (_("Choose Gamescope or ScopeBuddy to show its settings."));
			subtitle_label.set_xalign (0);
			subtitle_label.set_wrap (true);
			subtitle_label.add_css_class ("dim-label");

			content_box.append (title_label);
			content_box.append (subtitle_label);
			placeholder.append (content_box);

			return placeholder;
		}

		Gtk.Widget create_gamescope_page () {
			var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

			var grid = new Gtk.Grid ();
			grid.set_column_spacing (12);
			grid.set_row_spacing (12);
			grid.set_column_homogeneous (true);

			gamescope_fullscreen_tile = new LaunchOptionTile (_("Fullscreen"), _("Runs the game in a fullscreen Gamescope session."));
			gamescope_fullscreen_tile.toggle.notify["active"].connect (standard_control_changed);

			gamescope_vrr_tile = new LaunchOptionTile (_("VRR"), _("Matches your display's refresh rate to the game's FPS."));
			gamescope_vrr_tile.toggle.notify["active"].connect (standard_control_changed);

			gamescope_framerate_tile = new LaunchOptionSpinTile (_("Frame limit"), _("Caps the frame rate inside Gamescope."), _("FPS"), 30, 360, 60);
			gamescope_framerate_tile.toggle.notify["active"].connect (standard_control_changed);
			gamescope_framerate_tile.value_applied.connect (standard_control_changed);

			gamescope_resolution_field = new LaunchOptionResolutionField (_("Resolution"), _("Sets the Gamescope output resolution."));
			gamescope_resolution_field.toggle.notify["active"].connect (standard_control_changed);
			gamescope_resolution_field.dropdown.notify["selected"].connect (standard_control_changed);
			gamescope_resolution_field.value_applied.connect (standard_control_changed);

			grid.attach (gamescope_fullscreen_tile, 0, 0, 1, 1);
			grid.attach (gamescope_vrr_tile, 1, 0, 1, 1);
			grid.attach (gamescope_framerate_tile, 0, 1, 1, 1);
			grid.attach (gamescope_resolution_field, 1, 1, 1, 1);

			gamescope_args_field = new LaunchOptionEntryField (_("Additional Gamescope arguments"), _("Keeps extra Gamescope flags such as output or resolution tweaks."), _("Add Gamescope arguments"));
			gamescope_args_field.value_applied.connect (standard_control_changed);

			gamescope_advanced_revealer = new Gtk.Revealer ();
			gamescope_advanced_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
			gamescope_advanced_revealer.set_child (gamescope_args_field);

			page.append (grid);
			page.append (gamescope_advanced_revealer);

			return page;
		}

		Gtk.Widget create_scopebuddy_page () {
			var page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

			var grid = new Gtk.Grid ();
			grid.set_column_spacing (12);
			grid.set_row_spacing (12);
			grid.set_column_homogeneous (true);

			scopebuddy_auto_hdr_tile = new LaunchOptionTile (_("Auto HDR"), _("Turns HDR on automatically when your display supports it."));
			scopebuddy_auto_hdr_tile.toggle.notify["active"].connect (standard_control_changed);

			scopebuddy_auto_vrr_tile = new LaunchOptionTile (_("VRR"), _("Matches your display's refresh rate to the game's FPS."));
			scopebuddy_auto_vrr_tile.toggle.notify["active"].connect (standard_control_changed);

			scopebuddy_framerate_tile = new LaunchOptionSpinTile (_("Frame limit"), _("Caps the frame rate inside ScopeBuddy."), _("FPS"), 30, 360, 60);
			scopebuddy_framerate_tile.toggle.notify["active"].connect (standard_control_changed);
			scopebuddy_framerate_tile.value_applied.connect (standard_control_changed);

			scopebuddy_bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_HDR=1" }, scopebuddy_auto_hdr_tile.toggle));
			scopebuddy_bindings.append (new LaunchOptionBinding ({ "SCB_AUTO_VRR=1" }, scopebuddy_auto_vrr_tile.toggle));

			scopebuddy_resolution_field = new LaunchOptionResolutionField (_("Resolution"), _("Sets the ScopeBuddy output resolution."), true);
			scopebuddy_resolution_field.toggle.notify["active"].connect (standard_control_changed);
			scopebuddy_resolution_field.dropdown.notify["selected"].connect (standard_control_changed);
			scopebuddy_resolution_field.value_applied.connect (standard_control_changed);

			grid.attach (scopebuddy_auto_hdr_tile, 0, 0, 1, 1);
			grid.attach (scopebuddy_auto_vrr_tile, 1, 0, 1, 1);
			grid.attach (scopebuddy_framerate_tile, 0, 1, 1, 1);
			grid.attach (scopebuddy_resolution_field, 1, 1, 1, 1);

			scopebuddy_args_field = new LaunchOptionEntryField (_("Additional ScopeBuddy arguments"), _("Keeps extra ScopeBuddy flags such as preferred output selection."), _("Add ScopeBuddy arguments"));
			scopebuddy_args_field.value_applied.connect (standard_control_changed);

			scopebuddy_advanced_revealer = new Gtk.Revealer ();
			scopebuddy_advanced_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
			scopebuddy_advanced_revealer.set_child (scopebuddy_args_field);

			page.append (grid);
			page.append (scopebuddy_advanced_revealer);

			return page;
		}

		void reset_controls () {
			foreach (var binding in common_bindings) {
				binding.toggle.set_active (false);
			}

			foreach (var binding in scopebuddy_bindings) {
				binding.toggle.set_active (false);
			}

			gamescope_fullscreen_tile.toggle.set_active (false);
			gamescope_vrr_tile.toggle.set_active (false);
			gamescope_framerate_tile.toggle.set_active (false);
			gamescope_framerate_tile.set_value (60);
			gamescope_resolution_field.reset ();
			scopebuddy_framerate_tile.toggle.set_active (false);
			scopebuddy_framerate_tile.set_value (60);
			additional_args_tile.toggle.set_active (false);
			command_tile.toggle.set_active (false);
			skip_launcher_tile.toggle.set_active (false);

			additional_args_field.set_text ("");
			scopebuddy_resolution_field.reset ();
			gamescope_args_field.set_text ("");
			scopebuddy_args_field.set_text ("");
		}

		void standard_control_changed () {
			if (refreshing_controls)
				return;

			maybe_auto_enable_command ();
			refresh_preview ();
			content_changed ();
		}

		void refresh_advanced_visibility () {
			var is_advanced = advanced_visible;
			preview_revealer.set_reveal_child (is_advanced);
			more_options_revealer.set_reveal_child (is_advanced);
			gamescope_advanced_revealer.set_reveal_child (is_advanced);
			scopebuddy_advanced_revealer.set_reveal_child (is_advanced);
			advanced_options_revealer.set_reveal_child (is_advanced);
			additional_args_revealer.set_reveal_child (is_advanced && additional_args_tile.toggle.get_active ());
			wrapper_options_revealer.set_reveal_child (get_selected_wrapper_mode () != WrapperMode.NONE);
		}

		void additional_args_toggle_changed () {
			if (refreshing_controls)
				return;

			refresh_advanced_visibility ();
			if (additional_args_tile.toggle.get_active () && additional_args_revealer.get_child_revealed ())
				additional_args_field.focus_entry ();
			maybe_auto_enable_command ();
			refresh_preview ();
			content_changed ();
		}

		void command_toggle_changed () {
			if (refreshing_controls)
				return;

			if (!command_tile.toggle.get_active () && skip_launcher_tile.toggle.get_active ()) {
				refreshing_controls = true;
				skip_launcher_tile.toggle.set_active (false);
				refreshing_controls = false;
			}

			can_auto_enable_command = false;
			refresh_preview ();
			content_changed ();
		}

		void wrapper_selection_changed () {
			if (refreshing_controls)
				return;

			refresh_advanced_visibility ();
			maybe_auto_enable_command ();
			refresh_preview ();
			content_changed ();
		}

		bool should_show_advanced_controls () {
			return vkbasalt_tile.toggle.get_active ()
				|| wined3d_tile.toggle.get_active ()
				|| nvapi_tile.toggle.get_active ()
				|| additional_args_tile.toggle.get_active ()
				|| additional_args_field.get_text () != ""
				|| gamescope_args_field.get_text () != ""
				|| scopebuddy_args_field.get_text () != ""
				|| skip_launcher_tile.toggle.get_active ();
		}

		void maybe_auto_enable_command () {
			if (!can_auto_enable_command || command_tile.toggle.get_active () || !has_structured_content ())
				return;

			refreshing_controls = true;
			command_tile.toggle.set_active (true);
			refreshing_controls = false;

			can_auto_enable_command = false;
		}

		bool has_structured_content () {
			foreach (var binding in common_bindings) {
				if (binding.toggle.get_active ())
					return true;
			}

			if (additional_args_tile.toggle.get_active () && additional_args_field.get_text () != "")
				return true;

			if (skip_launcher_tile.toggle.get_active ())
				return true;

			switch (get_selected_wrapper_mode ()) {
				case WrapperMode.GAMESCOPE:
					if (gamescope_fullscreen_tile.toggle.get_active () || gamescope_vrr_tile.toggle.get_active () || gamescope_framerate_tile.toggle.get_active () || gamescope_resolution_field.has_resolution ())
						return true;

					if (gamescope_args_field.get_text () != "")
						return true;

					return false;
				case WrapperMode.SCOPEBUDDY:
					foreach (var binding in scopebuddy_bindings) {
						if (binding.toggle.get_active ())
							return true;
					}

					if (scopebuddy_framerate_tile.toggle.get_active ())
						return true;

					if (!scopebuddy_resolution_field.is_default ())
						return true;

					if (scopebuddy_args_field.get_text () != "")
						return true;

					return false;
				default:
					return false;
			}
		}

		Gee.ArrayList<string> get_command_segments () {
			var segments = new Gee.ArrayList<string> ();
			var selected_wrapper_mode = get_selected_wrapper_mode ();

			append_binding_segments (segments, common_bindings);
			if (additional_args_tile.toggle.get_active ())
				append_segments_from_text (segments, additional_args_field.get_text ());

			switch (selected_wrapper_mode) {
				case WrapperMode.GAMESCOPE:
					segments.add ("gamescope");

					if (gamescope_fullscreen_tile.toggle.get_active ())
						segments.add ("-f");

					if (gamescope_vrr_tile.toggle.get_active ())
						segments.add ("--adaptive-sync");

					if (gamescope_framerate_tile.toggle.get_active ())
						segments.add ("-r %d".printf (gamescope_framerate_tile.get_value_as_int ()));

					if (gamescope_resolution_field.has_resolution ()) {
						int width;
						int height;
						gamescope_resolution_field.get_resolution (out width, out height);
						segments.add ("-W %d".printf (width));
						segments.add ("-H %d".printf (height));
					}

					append_segments_from_text (segments, gamescope_args_field.get_text ());
					break;
				case WrapperMode.SCOPEBUDDY:
					append_binding_segments (segments, scopebuddy_bindings);

					if (scopebuddy_resolution_field.is_auto ())
						segments.add ("SCB_AUTO_RES=1");

					segments.add ("scopebuddy");

					if (scopebuddy_framerate_tile.toggle.get_active ())
						segments.add ("-r %d".printf (scopebuddy_framerate_tile.get_value_as_int ()));

					if (scopebuddy_resolution_field.has_resolution ()) {
						int width;
						int height;
						scopebuddy_resolution_field.get_resolution (out width, out height);
						segments.add ("-W %d".printf (width));
						segments.add ("-H %d".printf (height));
					}

					append_segments_from_text (segments, scopebuddy_args_field.get_text ());
					break;
				default:
					break;
			}

			if (command_tile.toggle.get_active ()) {
				if (selected_wrapper_mode != WrapperMode.NONE)
					segments.add ("-- %command%");
				else
					segments.add ("%command%");

				if (skip_launcher_tile.toggle.get_active ())
					segments.add ("-skip-launcher");
			}

			return segments;
		}

		void append_binding_segments (Gee.ArrayList<string> segments, List<LaunchOptionBinding> bindings) {
			foreach (var binding in bindings) {
				if (!binding.toggle.get_active ())
					continue;

				foreach (var token in binding.tokens) {
					segments.add (token);
				}
			}
		}

		void append_segments_from_text (Gee.ArrayList<string> segments, string launch_options) {
			foreach (var token in get_launch_option_tokens (launch_options)) {
				if (token == "")
					continue;

				segments.add (token);
			}
		}

		void refresh_preview () {
			preview_field.preview_label.set_markup (build_preview_markup ());
		}

		string build_preview_markup () {
			var segments = get_command_segments ();
			if (segments.size == 0)
				return "<tt><span foreground='#8b949e'>%s</span></tt>".printf (Markup.escape_text (_("No launch options configured yet.")));

			string[] preview_colors = {
				"#79c0ff",
				"#ff938a",
				"#7ee787",
				"#d2a8ff",
				"#e3b341",
				"#56d4dd"
			};
			var markup = new StringBuilder ();
			markup.append ("<tt>");

			for (var index = 0; index < segments.size; index++) {
				if (index > 0)
					markup.append (" ");

				var escaped_segment = Markup.escape_text (segments[index]);
				markup.append ("<span foreground='%s'>%s</span>".printf (preview_colors[index % preview_colors.length], escaped_segment));
			}

			markup.append ("</tt>");

			return markup.str;
		}

		void apply_bindings_from_tokens (List<LaunchOptionBinding> bindings, string[] tokens, bool[] consumed) {
			foreach (var binding in bindings) {
				var token_indexes = new Gee.ArrayList<int> ();
				var all_tokens_present = true;

				foreach (var token in binding.tokens) {
					var token_index = get_unconsumed_token_index (tokens, token, consumed);
					if (token_index < 0) {
						all_tokens_present = false;
						break;
					}

					token_indexes.add (token_index);
				}

				if (!all_tokens_present)
					continue;

				binding.toggle.set_active (true);
				foreach (var token_index in token_indexes) {
					consumed[token_index] = true;
				}
			}
		}

		void parse_gamescope_tokens (string[] tokens, bool[] consumed) {
			var wrapper_index = get_first_present_index (tokens, { "gamescope" });
			if (wrapper_index < 0)
				return;

			consumed[wrapper_index] = true;

			var end_index = get_wrapper_end_index (tokens, wrapper_index, consumed);
			var extra_args = new StringBuilder ();

			for (var index = wrapper_index + 1; index < end_index; index++) {
				var token = tokens[index];

				if (token == "-f") {
					gamescope_fullscreen_tile.toggle.set_active (true);
					consumed[index] = true;
					continue;
				}

				if (token == "--adaptive-sync") {
					gamescope_vrr_tile.toggle.set_active (true);
					consumed[index] = true;
					continue;
				}

				if (token == "-r" && index + 1 < end_index) {
					int framerate;
					if (int.try_parse (tokens[index + 1], out framerate)) {
						gamescope_framerate_tile.toggle.set_active (true);
						gamescope_framerate_tile.set_value (framerate);
						consumed[index] = true;
						consumed[index + 1] = true;
						index++;
						continue;
					}
				}

				if (token == "-W" && index + 3 < end_index && tokens[index + 2] == "-H") {
					int width = 0;
					int height = 0;
					if (int.try_parse (tokens[index + 1], out width) && int.try_parse (tokens[index + 3], out height)) {
						gamescope_resolution_field.set_resolution (width, height);
						consumed[index] = true;
						consumed[index + 1] = true;
						consumed[index + 2] = true;
						consumed[index + 3] = true;
						index += 3;
						continue;
					}
				}

				append_token (extra_args, token);
				consumed[index] = true;
			}

			gamescope_args_field.set_text (extra_args.str);
		}

		void parse_scopebuddy_tokens (string[] tokens, bool[] consumed) {
			apply_bindings_from_tokens (scopebuddy_bindings, tokens, consumed);

			var auto_resolution_index = get_unconsumed_token_index (tokens, "SCB_AUTO_RES=1", consumed);
			if (auto_resolution_index >= 0) {
				scopebuddy_resolution_field.set_auto ();
				consumed[auto_resolution_index] = true;
			}

			var wrapper_index = get_first_present_index (tokens, { "scopebuddy", "scb" });
			if (wrapper_index < 0)
				return;

			consumed[wrapper_index] = true;

			var end_index = get_wrapper_end_index (tokens, wrapper_index, consumed);
			var extra_args = new StringBuilder ();

			for (var index = wrapper_index + 1; index < end_index; index++) {
				if (tokens[index] == "-r" && index + 1 < end_index) {
					int framerate;
					if (int.try_parse (tokens[index + 1], out framerate)) {
						scopebuddy_framerate_tile.toggle.set_active (true);
						scopebuddy_framerate_tile.set_value (framerate);
						consumed[index] = true;
						consumed[index + 1] = true;
						index++;
						continue;
					}
				}

				if (tokens[index] == "-W" && index + 3 < end_index && tokens[index + 2] == "-H") {
					int width = 0;
					int height = 0;
					if (int.try_parse (tokens[index + 1], out width) && int.try_parse (tokens[index + 3], out height)) {
						scopebuddy_resolution_field.set_resolution (width, height);
						consumed[index] = true;
						consumed[index + 1] = true;
						consumed[index + 2] = true;
						consumed[index + 3] = true;
						index += 3;
						continue;
					}
				}

				append_token (extra_args, tokens[index]);
				consumed[index] = true;
			}

			scopebuddy_args_field.set_text (extra_args.str);
		}

		WrapperMode detect_wrapper_mode (string[] tokens) {
			var gamescope_index = get_first_present_index (tokens, { "gamescope" });
			var scopebuddy_index = get_first_present_index (tokens, { "scopebuddy", "scb" });

			if (gamescope_index >= 0 && scopebuddy_index >= 0)
				return WrapperMode.NONE;

			if (gamescope_index >= 0)
				return WrapperMode.GAMESCOPE;

			if (scopebuddy_index >= 0)
				return WrapperMode.SCOPEBUDDY;

			return WrapperMode.NONE;
		}

		int get_wrapper_end_index (string[] tokens, int wrapper_index, bool[] consumed) {
			var command_index = get_token_index (tokens, "%command%");
			if (command_index > wrapper_index && command_index > 0 && tokens[command_index - 1] == "--") {
				consumed[command_index - 1] = true;
				return command_index - 1;
			}

			return tokens.length;
		}

		int get_first_present_index (string[] tokens, string[] candidates) {
			for (var index = 0; index < tokens.length; index++) {
				foreach (var candidate in candidates) {
					if (tokens[index] == candidate)
						return index;
				}
			}

			return -1;
		}

		int get_unconsumed_token_index (string[] tokens, string token, bool[] consumed) {
			for (var index = 0; index < tokens.length; index++) {
				if (!consumed[index] && tokens[index] == token)
					return index;
			}

			return -1;
		}

		int get_token_index (string[] tokens, string token) {
			for (var index = 0; index < tokens.length; index++) {
				if (tokens[index] == token)
					return index;
			}

			return -1;
		}

		string join_unconsumed_tokens (string[] tokens, bool[] consumed) {
			var output = new StringBuilder ();

			for (var index = 0; index < tokens.length; index++) {
				if (consumed[index] || tokens[index] == "")
					continue;

				append_token (output, tokens[index]);
			}

			return output.str;
		}

		string[] get_launch_option_tokens (string launch_options) {
			return normalize_launch_options (launch_options).split (" ");
		}

		string normalize_launch_options (string launch_options) {
			var output = new StringBuilder ();

			foreach (var token in launch_options.strip ().split (" ")) {
				if (token == "")
					continue;

				append_token (output, token);
			}

			return output.str;
		}

		WrapperMode get_selected_wrapper_mode () {
			switch (wrapper_stack.get_visible_child_name ()) {
				case "gamescope":
					return WrapperMode.GAMESCOPE;
				case "scopebuddy":
					return WrapperMode.SCOPEBUDDY;
				default:
					return WrapperMode.NONE;
			}
		}

		void set_selected_wrapper_mode (WrapperMode wrapper_mode) {
			switch (wrapper_mode) {
				case WrapperMode.GAMESCOPE:
					wrapper_stack.set_visible_child_name ("gamescope");
					break;
				case WrapperMode.SCOPEBUDDY:
					wrapper_stack.set_visible_child_name ("scopebuddy");
					break;
				default:
					wrapper_stack.set_visible_child_name ("none");
					break;
			}
		}

		void append_token (StringBuilder output, string token) {
			if (output.len > 0)
				output.append (" ");

			output.append (token);
		}
	}
}
