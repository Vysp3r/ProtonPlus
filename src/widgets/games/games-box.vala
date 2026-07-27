namespace ProtonPlus.Widgets.Games {
    public class Box : Gtk.Box {
        bool error { get; set; }
        bool invalid { get; set; }
        Models.Launcher launcher;

        Gtk.Image image;
        Adw.StatusPage status_page;
        MassEditButton mass_edit_button;
        Gtk.ActionBar action_bar;
        Gtk.Button back_button;
        Gtk.Button clear_button;
        Gtk.Button apply_button;
        Gtk.SearchEntry search_entry;
        Gtk.CheckButton check_button;
        Gtk.Label prefix_label;
        Gtk.Label compatibility_tool_label;
        Gtk.Label other_label;
        Gtk.SizeGroup prefix_column_size_group;
        Gtk.SizeGroup tool_column_size_group;
        Gtk.SizeGroup actions_column_size_group;
        Gtk.SizeGroup filter_column_size_group;
        Gtk.Box header_box;
        Gtk.Box headered_list_box;
        Gtk.Box games_page_box;
        Gtk.Stack content_stack;
        Gtk.Stack list_stack;
        Adw.StatusPage empty_status_page;
        Gtk.ScrolledWindow scrolled_window;
        Gtk.ListBox game_list_box;
        Gtk.MenuButton filter_button;
        Gtk.CheckButton all_filter_check;
        Gtk.CheckButton non_steam_filter_check;
        Gtk.CheckButton native_filter_check;
        Adw.Spinner spinner;
        Gtk.Overlay overlay;
        MassEditView mass_edit_view;
        ListStore model;
        Gtk.PropertyExpression expression;
        Gtk.Box action_bar_box;
        Gtk.MenuButton selection_button;
        Gtk.ListBox selection_list_box;
        Gtk.Popover selection_popover;
        Gtk.Label selection_popover_title;
        string search_query = "";
        uint search_timeout_id = 0;
        bool updating_selection_toggle = false;

        construct {
            image = new Gtk.Image ();

            status_page = new Adw.StatusPage ();
            status_page.set_visible (false);

            game_list_box = new Gtk.ListBox ();
            game_list_box.set_hexpand (true);
            game_list_box.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            game_list_box.add_css_class ("boxed-list");
            game_list_box.add_css_class ("list-content");
            game_list_box.set_filter_func (filter_game_row);
            game_list_box.set_sort_func ((row1, row2) => {
                var name1 = ((GameRow) row1).game.name;
                var name2 = ((GameRow) row2).game.name;

                return strcmp (name1, name2);
            });

            spinner = new Adw.Spinner ();
            spinner.set_halign (Gtk.Align.CENTER);
            spinner.set_valign (Gtk.Align.CENTER);
            spinner.set_size_request (32, 32);

            empty_status_page = new Adw.StatusPage () {
                title = _("No games found"),
                description = _("Try a different search term or filter."),
                icon_name = "magnifying-glass-symbolic"
            };

            list_stack = new Gtk.Stack ();
            list_stack.set_hexpand (true);
            list_stack.set_vexpand (true);
            list_stack.add_named (game_list_box, "list");
            list_stack.add_named (empty_status_page, "empty");

            overlay = new Gtk.Overlay ();
            overlay.set_hexpand (true);
            overlay.set_child (list_stack);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_hexpand (true);
            scrolled_window.set_vexpand (true);
            scrolled_window.set_child (overlay);
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

            mass_edit_button = new MassEditButton (game_list_box);
            mass_edit_button.set_visible (false);
            mass_edit_button.mass_edit_requested.connect (open_mass_edit);

            back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic");
            back_button.add_css_class ("flat");
            back_button.set_tooltip_text (_("Back"));
            back_button.clicked.connect (show_games_list_page);
            back_button.set_visible (false);

            clear_button = new Gtk.Button.from_icon_name ("eraser-symbolic");
            clear_button.add_css_class ("destructive-action");
            clear_button.set_tooltip_text (_("Clear the current launch options"));
            clear_button.set_visible (false);

            apply_button = new Gtk.Button.from_icon_name ("floppy-disk-symbolic");
            apply_button.add_css_class ("suggested-action");
            apply_button.set_tooltip_text (_("Apply the current modification"));
            apply_button.set_visible (false);

            selection_list_box = new Gtk.ListBox ();
            selection_list_box.set_selection_mode (Gtk.SelectionMode.NONE);
            selection_list_box.add_css_class ("selection-popover-list");

            var selection_scrolled_window = new Gtk.ScrolledWindow ();
            selection_scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            selection_scrolled_window.set_max_content_height (300);
            selection_scrolled_window.set_propagate_natural_height (true);
            selection_scrolled_window.set_child (selection_list_box);

            selection_popover_title = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                xalign = 0,
                ellipsize = Pango.EllipsizeMode.END
            };
            selection_popover_title.add_css_class ("heading");

            var selection_popover_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            selection_popover_content.add_css_class ("selection-popover-content");
            selection_popover_content.append (selection_popover_title);
            selection_popover_content.append (selection_scrolled_window);

            selection_popover = new Gtk.Popover ();
            selection_popover.set_child (selection_popover_content);

            selection_button = new Gtk.MenuButton ();
            selection_button.set_popover (selection_popover);
            selection_button.set_visible (false);
            selection_button.add_css_class ("flat");
            selection_button.add_css_class ("bold");

            all_filter_check = new Gtk.CheckButton ();
            all_filter_check.set_label (_("All"));
            all_filter_check.active = true;

            native_filter_check = new Gtk.CheckButton ();
            native_filter_check.set_label (_("Native"));
            native_filter_check.set_group (all_filter_check);

            non_steam_filter_check = new Gtk.CheckButton ();
            non_steam_filter_check.set_label (_("Non-Steam"));
            non_steam_filter_check.set_group (all_filter_check);

            var filter_popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            filter_popover_box.set_margin_top (12);
            filter_popover_box.set_margin_bottom (12);
            filter_popover_box.set_margin_start (12);
            filter_popover_box.set_margin_end (12);
            filter_popover_box.append (all_filter_check);
            filter_popover_box.append (native_filter_check);
            filter_popover_box.append (non_steam_filter_check);

            var filter_popover = new Gtk.Popover ();
            filter_popover.set_child (filter_popover_box);

            all_filter_check.toggled.connect (() => {
                if (all_filter_check.active) {
                    refilter_games ();
                    update_filter_button_state ();
                    filter_popover.popdown ();
                }
            });

            native_filter_check.toggled.connect (() => {
                if (native_filter_check.active) {
                    refilter_games ();
                    update_filter_button_state ();
                    filter_popover.popdown ();
                }
            });

            non_steam_filter_check.toggled.connect (() => {
                if (non_steam_filter_check.active) {
                    refilter_games ();
                    update_filter_button_state ();
                    filter_popover.popdown ();
                }
            });

            filter_button = new Gtk.MenuButton () {
                valign = Gtk.Align.CENTER,
                icon_name = "filter-2-symbolic",
                popover = filter_popover,
                tooltip_text = _("Filter"),
                visible = false,
                css_classes = { "flat" },
            };
            update_filter_button_state ();

            filter_column_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            filter_column_size_group.add_widget (filter_button);

            action_bar_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 15);
            action_bar_box.set_halign (Gtk.Align.CENTER);

            action_bar_box.append (mass_edit_button);

            action_bar = new Gtk.ActionBar ();
            action_bar.set_center_widget (action_bar_box);

            search_entry = new Gtk.SearchEntry () {
                placeholder_text = _("Search games"),
                hexpand = true
            };
            search_entry.add_css_class ("flat");
            search_entry.changed.connect (schedule_search_filter);

            check_button = new Gtk.CheckButton ();
            check_button.set_size_request (30, 26);
            check_button.set_tooltip_text (_("Select all visible games"));
            check_button.toggled.connect (() => {
                if (updating_selection_toggle)
                    return;

                var is_active = check_button.get_active ();
                var child = game_list_box.get_first_child ();
                while (child != null) {
                    if (child is GameRow && child.get_visible ()) {
                        ((GameRow) child).selected = is_active;
                    }
                    child = child.get_next_sibling ();
                }
                update_selection_controls ();
            });

            prefix_label = new Gtk.Label (_("Prefix"));
            prefix_label.set_xalign (0);
            prefix_label.set_size_request (110, 0);

            compatibility_tool_label = new Gtk.Label (_("Tool"));
            compatibility_tool_label.set_xalign (0);
            compatibility_tool_label.set_size_request (254, 0);

            other_label = new Gtk.Label (_("Actions"));
            other_label.set_xalign (0);
            other_label.set_size_request (122, 0);

            prefix_column_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            prefix_column_size_group.add_widget (prefix_label);

            tool_column_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            tool_column_size_group.add_widget (compatibility_tool_label);

            actions_column_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            actions_column_size_group.add_widget (other_label);

            header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.set_hexpand (true);

            header_box.add_css_class ("list-header");
            header_box.set_overflow (Gtk.Overflow.HIDDEN);
            header_box.append (check_button);
            header_box.append (search_entry);
            header_box.append (filter_button);
            header_box.append (prefix_label);
            header_box.append (compatibility_tool_label);
            header_box.append (other_label);

            headered_list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            headered_list_box.set_hexpand (true);
            headered_list_box.add_css_class ("card");
            headered_list_box.add_css_class ("transparent-card");
            headered_list_box.set_overflow (Gtk.Overflow.HIDDEN);
            headered_list_box.append (header_box);
            headered_list_box.append (scrolled_window);

            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            games_page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            games_page_box.set_hexpand (true);
            games_page_box.set_vexpand (true);
            games_page_box.append (headered_list_box);
            games_page_box.append (status_page);

            var games_page_clamp = new Adw.Clamp ();
            games_page_clamp.set_vexpand (true);
            games_page_clamp.set_maximum_size (975);
            games_page_clamp.set_margin_top (12);
            games_page_clamp.set_margin_bottom (12);
            games_page_clamp.set_margin_start (12);
            games_page_clamp.set_margin_end (12);
            games_page_clamp.set_child (games_page_box);

            mass_edit_view = new MassEditView (back_button, clear_button, apply_button, selection_button);
            mass_edit_view.back_requested.connect (show_games_list_page);

            content_stack = new Gtk.Stack ();
            content_stack.set_vexpand (true);
            content_stack.set_hexpand (true);
            content_stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            content_stack.add_named (games_page_clamp, "main");
            content_stack.add_named (mass_edit_view, "mass-edit");
            content_stack.set_visible_child_name ("main");

            content_stack.notify["visible-child-name"].connect (() => {
                var is_mass_edit = content_stack.get_visible_child_name () == "mass-edit";

                back_button.set_visible (is_mass_edit);
                clear_button.set_visible (is_mass_edit);
                apply_button.set_visible (is_mass_edit);
                action_bar_box.set_visible (!is_mass_edit);
                action_bar.set_visible (!is_mass_edit && mass_edit_button.get_visible ());
            });

            expression = new Gtk.PropertyExpression (typeof (Models.CompatibilityTool), null, "display_title");

            append (content_stack);
            append (action_bar);
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            this.launcher = launcher;

            filter_button.set_visible (launcher.has_library_support);
            non_steam_filter_check.set_visible (launcher is Models.Launchers.Steam);

            if (launcher.has_library_support) {
                if (invalid) {
                    show_normal ();

                    invalid = false;
                }

                if (launcher is Models.Launchers.Steam) {
                    var steam_launcher = (Models.Launchers.Steam) launcher;

                    if (steam_launcher.profiles.length () == 0) {
                        error = true;
                        show_status_box (
                            "bug-symbolic",
                            _("No profile was found."),
                            "%s\n%s".printf (
                                _("Make sure to connect yourself at least once on Steam."),
                                _("If you think this is an issue, make sure to report this on GitHub.")
                            )
                        );
                    } else {
                        load_games ();
                    }
                }
            } else {
                invalid = true;
                show_status_box (
                    launcher.icon_path,
                    _("Unsupported launcher"),
                    "%s\n%s".printf (
                        _("%s is currently not supported.").printf (launcher.title),
                        _("If you want me to speed up the development make sure to show your support!")
                    ),
                    true
                );
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

        public void load_games () {
            spinner.set_visible (true);

            if (search_timeout_id != 0) {
                Source.remove (search_timeout_id);
                search_timeout_id = 0;
            }
            search_query = search_entry.get_text ().down ();

            game_list_box.remove_all ();

            overlay.add_overlay (spinner);

            model = new ListStore (typeof (Models.CompatibilityTool));
            model.append (new Models.CompatibilityTool (_("Default"), _("Default")));
            foreach (var ct in launcher.compatibility_tools)
                model.append (ct);

            foreach (var game in launcher.games) {
                var game_row = new GameRow (
                    game,
                    launcher.has_library_support,
                    prefix_column_size_group,
                    tool_column_size_group,
                    actions_column_size_group,
                    filter_column_size_group
                );
                game_row.mass_edit_requested.connect ((row) => {
                    open_mass_edit ({ row });
                });
                game_row.notify["selected"].connect (() => {
                    if (game_row.selected)
                        game_list_box.select_row (game_row);
                    else
                        game_list_box.unselect_row (game_row);
                    update_selection_controls ();
                });

                game_list_box.append (game_row);
            }

            update_empty_state ();
            update_selection_controls ();

            overlay.remove_overlay (spinner);

            spinner.set_visible (false);
        }

        void schedule_search_filter () {
            search_query = search_entry.get_text ().down ();

            if (search_timeout_id != 0)
                Source.remove (search_timeout_id);

            search_timeout_id = Timeout.add (150, () => {
                search_timeout_id = 0;
                refilter_games ();

                return false;
            });
        }

        void refilter_games () {
            game_list_box.invalidate_filter ();
            update_empty_state ();
            update_selection_controls ();
        }

        void update_filter_button_state () {
            if (!all_filter_check.active)
                filter_button.add_css_class ("games-filter-active");
            else
                filter_button.remove_css_class ("games-filter-active");

            if (native_filter_check.active)
                filter_button.set_tooltip_text (_("Filter: Native"));
            else if (non_steam_filter_check.active)
                filter_button.set_tooltip_text (_("Filter: Non-Steam"));
            else
                filter_button.set_tooltip_text (_("Filter: All games"));
        }

        void update_empty_state () {
            bool has_visible = false;
            var child = game_list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow && filter_game_row ((Gtk.ListBoxRow) child)) {
                    has_visible = true;
                    break;
                }
                child = child.get_next_sibling ();
            }

            if (has_visible) {
                list_stack.set_visible_child_name ("list");
                return;
            }

            if (search_query.strip () != "") {
                empty_status_page.set_title (_("No matching games"));
                empty_status_page.set_description (_("Try a different search term or clear the search."));
                empty_status_page.set_icon_name ("magnifying-glass-symbolic");
            } else if (!all_filter_check.active) {
                empty_status_page.set_title (_("No games match this filter"));
                empty_status_page.set_description (_("Choose All games to see your complete library."));
                empty_status_page.set_icon_name ("filter-2-symbolic");
            } else {
                empty_status_page.set_title (_("No games found"));
                empty_status_page.set_description (_("No games are available for this launcher."));
                empty_status_page.set_icon_name ("gamepad-symbolic");
            }

            list_stack.set_visible_child_name ("empty");
        }

        bool filter_game_row (Gtk.ListBoxRow row) {
            var game_row = (GameRow) row;
            var game = game_row.game;

            if (!game_row.matches_search (search_query))
                return false;

            if (non_steam_filter_check.active)
                return game is Models.Games.Steam && ((Models.Games.Steam) game).is_non_steam;

            if (native_filter_check.active)
                return game.is_native;

            return true;
        }

        void update_selection_controls () {
            int selected_count = 0;
            int visible_count = 0;
            var child = game_list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow && child.get_visible ()) {
                    visible_count++;
                    if (((GameRow) child).selected)
                        selected_count++;
                }
                child = child.get_next_sibling ();
            }

            updating_selection_toggle = true;
            check_button.set_inconsistent (selected_count > 0 && selected_count < visible_count);
            check_button.set_active (visible_count > 0 && selected_count == visible_count);
            updating_selection_toggle = false;

            mass_edit_button.set_selected_count (selected_count);
            mass_edit_button.set_visible (selected_count >= 2);
            action_bar.set_visible (mass_edit_button.get_visible ());
        }

        void open_mass_edit (GameRow[] rows) {
            mass_edit_view.load (rows, model, expression);
            content_stack.set_visible_child_name ("mass-edit");

            selection_button.set_label (mass_edit_view.get_selection_text ());
            selection_button.set_visible (true);
            selection_popover_title.set_label (mass_edit_view.get_selection_text ());

            selection_list_box.remove_all ();
            foreach (var row in rows) {
                var title = new Gtk.Label (row.game.name) {
                    halign = Gtk.Align.START,
                    hexpand = true,
                    xalign = 0,
                    ellipsize = Pango.EllipsizeMode.END
                };

                var selection_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                selection_row.add_css_class ("selection-popover-row");
                selection_row.append (new Gtk.Image.from_icon_name ("gamepad-symbolic"));
                selection_row.append (title);
                selection_list_box.append (selection_row);
            }

            mass_edit_button.set_visible (false);
        }

        public void show_games_list_page () {
            content_stack.set_visible_child_name ("main");

            selection_button.set_visible (false);

            search_entry.text = "";
            all_filter_check.active = true;

            check_button.active = false;

            var child = game_list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow) {
                    ((GameRow) child).selected = false;
                }
                child = child.get_next_sibling ();
            }

            update_selection_controls ();
        }
    }
}
