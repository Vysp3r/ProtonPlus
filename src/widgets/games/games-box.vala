namespace ProtonPlus.Widgets {
    public class GamesBox : Gtk.Box {
        public delegate void load_steam_profile_func(Models.SteamProfile profile);

        public bool active { get; set; }
        bool error { get; set; }
        bool invalid { get; set; }
        Models.Launcher launcher;

        Gtk.Image image;
        Adw.StatusPage status_page;
        MassEditButton mass_edit_button;
        SwitchProfileButton switch_profile_button;
        Gtk.ActionBar action_bar;
        Gtk.Button back_button;
        Gtk.Button clear_button;
        Gtk.Button apply_button;
        Gtk.Box advanced_box;
        Gtk.Switch advanced_switch;
        Gtk.SearchEntry search_entry;
        Gtk.CheckButton check_button;
        Gtk.Label prefix_label;
        Gtk.Label compatibility_tool_label;
        Gtk.Label other_label;
        Gtk.Box header_box;
        Gtk.Box headered_list_box;
        Gtk.Box games_page_box;
        Gtk.Stack content_stack;
        Gtk.ScrolledWindow scrolled_window;
        Gtk.ListBox game_list_box;
        Gtk.Spinner spinner;
        Gtk.Overlay overlay;
        MassEditView mass_edit_view;
        ListStore model;
        Gtk.PropertyExpression expression;
        Gtk.Box action_bar_box;
        Gtk.Label selection_label;

        construct {
            image = new Gtk.Image();

            status_page = new Adw.StatusPage();
            status_page.set_visible (false);

            game_list_box = new Gtk.ListBox();
            game_list_box.set_hexpand (true);
            game_list_box.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            game_list_box.add_css_class ("boxed-list");
            game_list_box.add_css_class ("list-content");

            spinner = new Gtk.Spinner();
            spinner.set_halign (Gtk.Align.CENTER);
            spinner.set_valign (Gtk.Align.CENTER);
            spinner.set_size_request (200, 200);

            overlay = new Gtk.Overlay();
            overlay.set_hexpand (true);
            overlay.set_child (game_list_box);

            scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.set_hexpand (true);
            scrolled_window.set_vexpand (true);
            scrolled_window.set_child (overlay);
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

            mass_edit_button = new MassEditButton(game_list_box);
            mass_edit_button.set_visible (false);
            mass_edit_button.mass_edit_requested.connect (open_mass_edit);

            switch_profile_button = new SwitchProfileButton();

            back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic");
            back_button.add_css_class ("flat");
            back_button.set_tooltip_text (_ ("Back"));
            back_button.clicked.connect (show_games_list_page);
            back_button.set_visible (false);

            clear_button = new Gtk.Button.from_icon_name ("eraser-symbolic");
            clear_button.add_css_class ("flat");
            clear_button.add_css_class ("clear-button");
            clear_button.set_tooltip_text (_ ("Clear the current launch options"));
            clear_button.set_visible (false);

            apply_button = new Gtk.Button.from_icon_name ("floppy-disk-symbolic");
            apply_button.add_css_class ("suggested-action");
            apply_button.set_tooltip_text (_ ("Apply the current modification"));
            apply_button.set_visible (false);

            advanced_switch = new Gtk.Switch ();
            advanced_switch.set_valign (Gtk.Align.CENTER);

            advanced_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            advanced_box.set_valign (Gtk.Align.CENTER);
            advanced_box.append (new Gtk.Label (_ ("Advanced")));
            advanced_box.append (advanced_switch);
            advanced_box.set_visible (false);

            selection_label = new Gtk.Label ("");
            selection_label.set_visible (false);
            selection_label.add_css_class ("bold");

            action_bar_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            action_bar_box.set_halign (Gtk.Align.CENTER);

            action_bar_box.append (mass_edit_button);
            action_bar_box.append (switch_profile_button);

            var center_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            center_box.set_halign (Gtk.Align.CENTER);
            center_box.append (action_bar_box);
            center_box.append (selection_label);

            action_bar = new Gtk.ActionBar ();
            action_bar.set_center_widget (center_box);
            action_bar.pack_start (back_button);
            action_bar.pack_start (clear_button);
            action_bar.pack_end (apply_button);
            action_bar.pack_end (advanced_box);

            search_entry = new Gtk.SearchEntry() {
                placeholder_text = _ ("Name"),
                hexpand = true
            };
            search_entry.add_css_class ("flat");
            search_entry.changed.connect (load_games);

            check_button = new Gtk.CheckButton();
            check_button.set_size_request (26, 26);
            check_button.toggled.connect (() => {
                var is_active = check_button.get_active ();
                var child = game_list_box.get_first_child ();
                while (child != null) {
                    if (child is GameRow) {
                        ((GameRow) child).selected = is_active;
                    }
                    child = child.get_next_sibling ();
                }
            });

            prefix_label = new Gtk.Label(_ ("Prefix"));
            prefix_label.set_xalign (0);
            prefix_label.set_size_request (110, 0);

            compatibility_tool_label = new Gtk.Label(_ ("Tool"));
            compatibility_tool_label.set_xalign (0);
            compatibility_tool_label.set_size_request (254, 0);

            other_label = new Gtk.Label(_ ("Actions"));
            other_label.set_xalign (0);
            other_label.set_size_request (122, 0);

            header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            header_box.set_hexpand (true);

            header_box.add_css_class ("list-header");
            header_box.set_overflow (Gtk.Overflow.HIDDEN);
            header_box.append (check_button);
            header_box.append (search_entry);
            header_box.append (prefix_label);
            header_box.append (compatibility_tool_label);
            header_box.append (other_label);

            headered_list_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            headered_list_box.set_hexpand (true);
            headered_list_box.add_css_class ("card");
            headered_list_box.add_css_class ("transparent-card");
            headered_list_box.set_overflow (Gtk.Overflow.HIDDEN);
            headered_list_box.append (header_box);
            headered_list_box.append (scrolled_window);

            notify["active"].connect (() => {
                if (!active || error || !(launcher is Models.Launchers.Steam))
                return;

                var steam_launcher = launcher as Models.Launchers.Steam;

                if (steam_launcher.profiles.length () == 0) {
                    error = true;
                    show_status_box ("bug-symbolic", _ ("No profile was found."), "%s\n%s".printf (_ ("Make sure to connect yourself at least once on Steam."), _ ("If you think this is an issue, make sure to report this on GitHub.")));
                } else {
                    if (Globals.SETTINGS != null && Globals.SETTINGS.get_boolean ("steam-remember-last-profile")) {
                        var steam_id = Globals.SETTINGS.get_string ("steam-last-profile-id");
                        foreach (var profile in steam_launcher.profiles) {
                            if (profile.steam_id == steam_id) {
                                load_steam_profile (profile);
                                return;
                            }
                        }
                    }

                    if (steam_launcher.profiles.length () > 1) {
                        game_list_box.remove_all ();

                        var dialog = new ProfileDialog(steam_launcher, load_steam_profile);
                        dialog.present (Application.window);
                    } else {
                        load_steam_profile (steam_launcher.profiles.nth_data (0));
                    }
                }
            });

            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            games_page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            games_page_box.set_hexpand (true);
            games_page_box.set_vexpand (true);
            games_page_box.append (headered_list_box);
            games_page_box.append (status_page);

            mass_edit_view = new MassEditView (back_button, clear_button, apply_button, advanced_box, advanced_switch);
            mass_edit_view.back_requested.connect (show_games_list_page);

            content_stack = new Gtk.Stack ();
            content_stack.set_vexpand (true);
            content_stack.set_hexpand (true);
            content_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            content_stack.add_named (games_page_box, "main");
            content_stack.add_named (mass_edit_view, "mass-edit");
            content_stack.set_visible_child_name ("main");

            content_stack.notify["visible-child-name"].connect (() => {
                var is_launch_options = content_stack.get_visible_child_name () == "launch-options";

                back_button.set_visible (is_launch_options);
                clear_button.set_visible (is_launch_options);
                apply_button.set_visible (is_launch_options);
                advanced_box.set_visible (is_launch_options);
                action_bar_box.set_visible (!is_launch_options);
            });

            var clamp = new Adw.Clamp ();
            clamp.set_vexpand (true);
            clamp.set_maximum_size (975);
            clamp.set_margin_top (7);
            clamp.set_margin_bottom (12);
            clamp.set_margin_start (12);
            clamp.set_margin_end (12);
            clamp.set_child (content_stack);

            append (clamp);
            append (action_bar);
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            this.launcher = launcher;

            switch_profile_button.set_visible (false);

            if (launcher.has_library_support) {
                if (invalid) {
                    show_normal ();

                    invalid = false;
                }

                if (launcher is Models.Launchers.Steam) {
                    var steam_launcher = (Models.Launchers.Steam) launcher;

                    if (steam_launcher.profiles.length () > 1) {
                        switch_profile_button.set_visible (true);
                        switch_profile_button.load (steam_launcher, load_steam_profile, game_list_box);
                    }

                    notify_property ("active"); // Ensure that when the launcher is changed, but you're in the Games tab the profile dialog still shows up
                } else {
                    load_games ();
                }
            } else {
                invalid = true;
                show_status_box (launcher.icon_path, _ ("Unsupported launcher"), "%s\n%s".printf (_ ("%s is currently not supported.").printf (launcher.title), _ ("If you want me to speed up the development make sure to show your support!")), true);
            }
        }

        void show_normal () {
            error = false;

            action_bar.set_visible (true);
            headered_list_box.set_visible (true);

            status_page.set_visible (false);
        }

        void show_status_box (string icon, string title, string description, bool is_image = false) {
            action_bar.set_visible (false);
            headered_list_box.set_visible (false);

            if (is_image)
            image.set_from_resource (icon);
            else
            image.set_from_icon_name (icon);

            status_page.set_vexpand (true);
            status_page.set_hexpand (true);
            status_page.set_title (title);
            status_page.set_description (description);
            status_page.set_paintable (image.get_paintable ());
            status_page.set_visible (true);
        }

        void load_games () {
            if (!spinner.spinning)
            spinner.start ();

            game_list_box.remove_all ();

            overlay.add_overlay (spinner);

            model = new ListStore(typeof (Models.SimpleRunner));
            model.append (new Models.SimpleRunner(_ ("Default"), _ ("Default")));
            foreach (var ct in launcher.compatibility_tools)
            model.append (ct);

            expression = new Gtk.PropertyExpression(typeof (Models.SimpleRunner), null, "display_title");

            foreach (var game in launcher.games) {
                if (!game.name.down ().contains (search_entry.get_text ().down ()))
                continue;

                var game_row = new GameRow(game);
                game_row.mass_edit_requested.connect ((row) => {
                    open_mass_edit ({row});
                });
                game_row.notify["selected"].connect (() => {
                    if (game_row.selected)
                        game_list_box.select_row (game_row);
                    else
                        game_list_box.unselect_row (game_row);
                    update_mass_edit_button_visibility ();
                });

                game_list_box.append (game_row);
            }

            update_mass_edit_button_visibility ();

            game_list_box.set_sort_func ((row1, row2) => {
                var name1 = ((GameRow) row1).game.name;
                var name2 = ((GameRow) row2).game.name;

                return strcmp (name1, name2);
            });

            overlay.remove_overlay (spinner);

            spinner.stop ();
        }

        void load_steam_profile (Models.SteamProfile profile) {
            spinner.start ();

            var steam_launcher = (Models.Launchers.Steam) launcher;
            steam_launcher.switch_profile.begin (profile, (obj, res) => {
                load_games ();
            });
        }

        void update_mass_edit_button_visibility () {
            int selected_count = 0;
            var child = game_list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow) {
                    if (((GameRow) child).selected)
                        selected_count++;
                }
                child = child.get_next_sibling ();
            }
            mass_edit_button.set_visible (selected_count >= 2);
        }

        void open_mass_edit (GameRow[] rows) {
            mass_edit_view.load (rows, model, expression);
            content_stack.set_visible_child_name ("mass-edit");

            selection_label.set_text (mass_edit_view.get_selection_text ());
            selection_label.set_visible (true);
            action_bar_box.set_visible (false);

            back_button.set_visible (true);
            clear_button.set_visible (true);
            apply_button.set_visible (true);
            advanced_box.set_visible (true);

            mass_edit_button.set_visible (false);
            switch_profile_button.set_visible (false);
        }

        void show_games_list_page () {
            content_stack.set_visible_child_name ("main");

            selection_label.set_visible (false);
            action_bar_box.set_visible (true);

            back_button.set_visible (false);
            clear_button.set_visible (false);
            apply_button.set_visible (false);
            advanced_box.set_visible (false);

            update_mass_edit_button_visibility ();

            bool show_profile_button = false;
            if (launcher is Models.Launchers.Steam) {
                var steam_launcher = (Models.Launchers.Steam) launcher;

                if (steam_launcher.profiles.length () > 1)
                    show_profile_button = true;
            }
            switch_profile_button.set_visible (show_profile_button);
        }
    }
}
