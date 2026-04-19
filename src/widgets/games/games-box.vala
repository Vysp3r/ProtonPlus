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
        DefaultToolButton default_tool_button;
        SwitchProfileButton switch_profile_button;
        Gtk.ActionBar action_bar;
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
        ListStore model;
        Gtk.PropertyExpression expression;

        construct {
            image = new Gtk.Image();

            status_page = new Adw.StatusPage();
            status_page.set_visible (false);

            game_list_box = new Gtk.ListBox();
            game_list_box.set_hexpand (true);
            game_list_box.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            game_list_box.add_css_class ("boxed-list");
            game_list_box.add_css_class ("list-content");
            game_list_box.row_activated.connect (game_list_box_row_activated);

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
            mass_edit_button.mass_edit_requested.connect (open_mass_edit);

            default_tool_button = new DefaultToolButton();
            default_tool_button.default_tool_requested.connect (open_default_tool);

            switch_profile_button = new SwitchProfileButton();

            var action_bar_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            action_bar_box.set_halign (Gtk.Align.CENTER);

            action_bar_box.append (mass_edit_button);
            action_bar_box.append (default_tool_button);
            action_bar_box.append (switch_profile_button);

            action_bar = new Gtk.ActionBar ();
            action_bar.set_center_widget (action_bar_box);

            search_entry = new Gtk.SearchEntry() {
                placeholder_text = _ ("Name"),
                hexpand = true
            };
            search_entry.add_css_class ("flat");
            search_entry.changed.connect (load_games);

            check_button = new Gtk.CheckButton();
            check_button.set_size_request (26, 26);
            check_button.toggled.connect (() => {
                if (check_button.get_active ()) {
                    game_list_box.select_all ();
                } else {
                    game_list_box.unselect_all ();
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
            other_label.set_size_request (166, 0);

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

            var clamp = new Adw.Clamp ();
            clamp.set_vexpand (true);
            clamp.set_maximum_size (975);
            clamp.set_margin_top (7);
            clamp.set_margin_bottom (12);
            clamp.set_margin_start (12);
            clamp.set_margin_end (12);
            clamp.set_child (games_page_box);

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

                    default_tool_button.load (steam_launcher);

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
                game_row.launch_options_requested.connect (open_launch_options);
                game_row.notify["selected"].connect (() => {
                    if (game_row.selected)
                    game_list_box.select_row (game_row);
                    else
                    game_list_box.unselect_row (game_row);
                });

                game_list_box.append (game_row);
            }

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

        void game_list_box_row_activated (Gtk.ListBoxRow? row) {
            if (row == null || !(row is GameRow))
            return;

            var game_row = (GameRow) row;
            game_row.selected = !game_row.selected;
        }

        void open_launch_options (GameRow row) {
            Application.window.launch_options_view.load (row);
            activate_action_variant ("win.set-selected-view", "launch-options");
        }

        void open_mass_edit (GameRow[] rows) {
            Application.window.mass_edit_view.load (rows, model, expression);
            activate_action_variant ("win.set-selected-view", "mass-edit");
        }

        void open_default_tool (Models.Launchers.Steam launcher) {
            Application.window.default_tool_view.load (launcher);
            activate_action_variant ("win.set-selected-view", "default-tool");
        }
    }
}
