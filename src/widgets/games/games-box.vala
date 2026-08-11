namespace ProtonPlus.Widgets.Games {
    public class Box : Gtk.Box, Utils.ControllerNavigationHost,
        Utils.ControllerPageShortcuts {
        const int NARROW_VIEW_WIDTH = 700;

        bool error { get; set; }
        bool invalid { get; set; }
        bool narrow_view_active = false;
        Models.Launcher launcher;

        Gtk.Image image;
        Adw.StatusPage status_page;
        MassEditButton mass_edit_button;
        Gtk.SearchEntry search_entry;
        Gtk.CheckButton check_button;
        Gtk.Box games_card;
        Adw.NavigationView navigation_view;
        Adw.NavigationPage list_page;
        Adw.NavigationPage mass_edit_page;
        Gtk.Stack list_stack;
        Gtk.Stack views_stack;
        Adw.StatusPage empty_status_page;
        Gtk.ColumnView wide_view;
        Gtk.ListView narrow_view;
        Gtk.MenuButton filter_button;
        Gtk.CheckButton all_filter_check;
        Gtk.CheckButton non_steam_filter_check;
        Gtk.CheckButton native_filter_check;
        Adw.Spinner spinner;
        Gtk.Overlay overlay;
        MassEditView mass_edit_view;
        GameCollection games;
        ListStore compatibility_tool_model;
        Gtk.PropertyExpression expression;
        Gtk.MenuButton selection_button;
        Gtk.ListBox selection_list_box;
        Gtk.Popover selection_popover;
        Gtk.Label selection_popover_title;
        Gee.HashMap<GameListItem, GameRow> narrow_rows;
        Gee.HashMap<GameListItem, GameSelectionCell> wide_selection_cells;
        Gee.HashMap<GameListItem, GameActions> wide_action_cells;
        GameListItem? last_focused_item;
        string search_query = "";
        uint search_timeout_id = 0;
        uint focus_idle_id = 0;
        bool updating_selection_toggle = false;
        bool mass_edit_cleanup_pending = false;

        public signal void header_presentation_changed (Header.Presentation? presentation);

        construct {
            image = new Gtk.Image ();
            status_page = new Adw.StatusPage () {
                visible = false
            };

            games = new GameCollection ();
            games.state_changed.connect (() => {
                update_empty_state ();
                update_selection_controls ();
            });
            narrow_rows = new Gee.HashMap<GameListItem, GameRow> ();
            wide_selection_cells = new Gee.HashMap<GameListItem, GameSelectionCell> ();
            wide_action_cells = new Gee.HashMap<GameListItem, GameActions> ();

            wide_view = build_wide_view ();
            narrow_view = build_narrow_view ();

            views_stack = new Gtk.Stack () {
                hexpand = true,
                vexpand = true,
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                transition_duration = 150
            };
            views_stack.add_named (
                create_collection_scroller (wide_view), "wide"
            );
            views_stack.add_named (
                create_collection_scroller (narrow_view), "narrow"
            );
            views_stack.set_visible_child_name ("wide");

            var responsive_views = new Adw.BreakpointBin ();
            responsive_views.set_size_request (360, 1);
            responsive_views.set_child (views_stack);
            var narrow_breakpoint = new Adw.Breakpoint (
                new Adw.BreakpointCondition.length (
                    Adw.BreakpointConditionLengthType.MAX_WIDTH,
                    NARROW_VIEW_WIDTH,
                    Adw.LengthUnit.SP
                )
            );
            narrow_breakpoint.apply.connect (() => switch_collection_view (true));
            narrow_breakpoint.unapply.connect (() => switch_collection_view (false));
            responsive_views.add_breakpoint (narrow_breakpoint);

            spinner = new Adw.Spinner () {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            spinner.set_size_request (32, 32);

            empty_status_page = new Adw.StatusPage () {
                title = _("No games found"),
                description = _("Try a different search term or filter."),
                icon_name = "magnifying-glass-symbolic"
            };

            list_stack = new Gtk.Stack () {
                hexpand = true,
                vexpand = true
            };
            list_stack.add_named (responsive_views, "list");
            list_stack.add_named (empty_status_page, "empty");

            overlay = new Gtk.Overlay () {
                hexpand = true,
                vexpand = true,
                child = list_stack
            };

            mass_edit_button = new MassEditButton (focus_last_visible_game) {
                visible = false
            };
            mass_edit_button.mass_edit_requested.connect (() => {
                var selected = games.selected_items ();
                if (selected.length > 0) {
                    open_mass_edit (selected);
                    return;
                }
                var dialog = new Main.WarningDialog (
                    _("Warning"),
                    _("Please make sure to select at least one game before using the mass edit feature.")
                );
                Window.present_dialog_for_controller (
                    dialog, (Gtk.Window) mass_edit_button.get_root ()
                );
            });

            build_selection_popover ();
            build_filter_popover ();
            build_search_toolbar ();

            games_card = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true,
                overflow = Gtk.Overflow.HIDDEN
            };
            games_card.add_css_class ("card");
            games_card.add_css_class ("transparent-card");
            games_card.append (build_toolbar ());
            games_card.append (overlay);

            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            var games_page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                hexpand = true,
                vexpand = true
            };
            games_page_box.append (games_card);
            games_page_box.append (mass_edit_button);
            games_page_box.append (status_page);

            var games_page_clamp = new Adw.Clamp () {
                vexpand = true,
                maximum_size = 975,
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                child = games_page_box
            };

            mass_edit_view = new MassEditView (selection_button);
            mass_edit_view.back_requested.connect (() => pop_page ());
            list_page = new Adw.NavigationPage.with_tag (
                games_page_clamp, _("Games"), "list"
            );
            mass_edit_page = new Adw.NavigationPage.with_tag (
                mass_edit_view, _("Games"), "mass-edit"
            );
            navigation_view = new Adw.NavigationView () {
                vexpand = true,
                hexpand = true
            };
            navigation_view.add (list_page);
            navigation_view.add (mass_edit_page);
            navigation_view.popped.connect ((page) => {
                if (page == mass_edit_page)
                    cleanup_mass_edit_exit ();
            });
            navigation_view.notify["visible-page"].connect (() => {
                header_presentation_changed (get_header_presentation ());
            });
            navigation_view.notify_property ("visible-page");

            expression = new Gtk.PropertyExpression (
                typeof (Models.CompatibilityTool), null, "display_title"
            );
            append (navigation_view);
        }

        Gtk.ColumnView build_wide_view () {
            var view = new Gtk.ColumnView (games.selection_model) {
                hexpand = true,
                vexpand = true,
                show_column_separators = true,
                show_row_separators = true,
                single_click_activate = false
            };
            view.add_css_class ("list-content");

            var selection_column = new Gtk.ColumnViewColumn (
                "", create_selection_factory ()
            );
            selection_column.set_expand (false);
            view.append_column (selection_column);

            var title_column = new Gtk.ColumnViewColumn (
                _("Games"), create_text_factory (GameTextCellKind.TITLE)
            );
            title_column.set_expand (true);
            view.append_column (title_column);

            var prefix_column = new Gtk.ColumnViewColumn (
                _("Prefix"), create_text_factory (GameTextCellKind.PREFIX)
            );
            prefix_column.set_expand (false);
            view.append_column (prefix_column);

            var tool_column = new Gtk.ColumnViewColumn (
                _("Tool"), create_text_factory (GameTextCellKind.TOOL)
            );
            tool_column.set_expand (true);
            view.append_column (tool_column);

            var actions_column = new Gtk.ColumnViewColumn (
                _("Actions"), create_actions_factory ()
            );
            actions_column.set_expand (false);
            view.append_column (actions_column);
            return view;
        }

        Gtk.ListView build_narrow_view () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var row = new GameRow (open_single_game_edit, focus_narrow_relative);
                list_item.set_activatable (false);
                list_item.set_focusable (false);
                list_item.set_selectable (false);
                list_item.set_child (row);
            });
            factory.bind.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var item = list_item.get_item () as GameListItem;
                var row = list_item.get_child () as GameRow;
                if (item == null || row == null)
                    return;
                ((!) row).bind ((!) item);
                narrow_rows.set ((!) item, (!) row);
            });
            factory.unbind.connect ((object) => {
                var row = ((Gtk.ListItem) object).get_child () as GameRow;
                if (row == null)
                    return;
                var item = ((!) row).get_item ();
                if (item != null && narrow_rows.get ((!) item) == row)
                    narrow_rows.unset ((!) item);
                ((!) row).unbind ();
            });
            factory.teardown.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var row = list_item.get_child () as GameRow;
                row?.unbind ();
                list_item.set_child (null);
            });

            var view = new Gtk.ListView (games.selection_model, factory) {
                hexpand = true,
                vexpand = true,
                single_click_activate = false
            };
            view.add_css_class ("boxed-list");
            view.add_css_class ("list-content");
            return view;
        }

        Gtk.ScrolledWindow create_collection_scroller (Gtk.Widget view) {
            return new Gtk.ScrolledWindow () {
                hexpand = true,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                child = view
            };
        }

        Gtk.SignalListItemFactory create_selection_factory () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                list_item.set_activatable (false);
                list_item.set_focusable (false);
                list_item.set_selectable (false);
                list_item.set_child (new GameSelectionCell (
                    focus_wide_relative, focus_wide_actions
                ));
            });
            factory.bind.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var item = list_item.get_item () as GameListItem;
                var cell = list_item.get_child () as GameSelectionCell;
                if (item == null || cell == null)
                    return;
                ((!) cell).bind ((!) item);
                wide_selection_cells.set ((!) item, (!) cell);
            });
            factory.unbind.connect ((object) => {
                var cell = ((Gtk.ListItem) object).get_child () as GameSelectionCell;
                if (cell == null)
                    return;
                var item = ((!) cell).get_item ();
                if (item != null && wide_selection_cells.get ((!) item) == cell)
                    wide_selection_cells.unset ((!) item);
                ((!) cell).unbind ();
            });
            factory.teardown.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var cell = list_item.get_child () as GameSelectionCell;
                cell?.unbind ();
                list_item.set_child (null);
            });
            return factory;
        }

        Gtk.SignalListItemFactory create_text_factory (GameTextCellKind kind) {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                list_item.set_activatable (false);
                list_item.set_focusable (false);
                list_item.set_selectable (false);
                list_item.set_child (new GameTextCell (kind));
            });
            factory.bind.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var item = list_item.get_item () as GameListItem;
                var cell = list_item.get_child () as GameTextCell;
                if (item != null && cell != null)
                    ((!) cell).bind ((!) item);
            });
            factory.unbind.connect ((object) => {
                var cell = ((Gtk.ListItem) object).get_child () as GameTextCell;
                cell?.unbind ();
            });
            factory.teardown.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var cell = list_item.get_child () as GameTextCell;
                cell?.unbind ();
                list_item.set_child (null);
            });
            return factory;
        }

        Gtk.SignalListItemFactory create_actions_factory () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                list_item.set_activatable (false);
                list_item.set_focusable (false);
                list_item.set_selectable (false);
                list_item.set_child (new GameActions (
                    open_single_game_edit, focus_wide_relative, focus_wide_selection
                ));
            });
            factory.bind.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var item = list_item.get_item () as GameListItem;
                var actions = list_item.get_child () as GameActions;
                if (item == null || actions == null)
                    return;
                ((!) actions).bind ((!) item);
                wide_action_cells.set ((!) item, (!) actions);
            });
            factory.unbind.connect ((object) => {
                var actions = ((Gtk.ListItem) object).get_child () as GameActions;
                if (actions == null)
                    return;
                var item = ((!) actions).get_item ();
                if (item != null && wide_action_cells.get ((!) item) == actions)
                    wide_action_cells.unset ((!) item);
                ((!) actions).unbind ();
            });
            factory.teardown.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var actions = list_item.get_child () as GameActions;
                actions?.unbind ();
                list_item.set_child (null);
            });
            return factory;
        }

        void build_selection_popover () {
            selection_list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                focusable = false
            };
            selection_list_box.add_css_class ("selection-popover-list");
            var selection_scrolled_window = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                max_content_height = 300,
                propagate_natural_height = true,
                child = selection_list_box
            };
            selection_popover_title = new Gtk.Label ("") {
                halign = Gtk.Align.START,
                xalign = 0,
                ellipsize = Pango.EllipsizeMode.END
            };
            selection_popover_title.add_css_class ("heading");
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            content.add_css_class ("selection-popover-content");
            content.append (selection_popover_title);
            content.append (selection_scrolled_window);
            selection_popover = new Gtk.Popover () {
                child = content
            };
            selection_button = new Gtk.MenuButton () {
                popover = selection_popover,
                visible = false
            };
            Window.register_popover_for_controller (selection_popover, selection_button);
            selection_button.add_css_class ("flat");
            selection_button.add_css_class ("bold");
        }

        void build_filter_popover () {
            all_filter_check = new Gtk.CheckButton.with_label (_("All")) {
                active = true
            };
            native_filter_check = new Gtk.CheckButton.with_label (_("Native"));
            native_filter_check.set_group (all_filter_check);
            non_steam_filter_check = new Gtk.CheckButton.with_label (_("Non-Steam"));
            non_steam_filter_check.set_group (all_filter_check);

            var filter_popover_box = new ControllerChoiceBox () {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };
            filter_popover_box.append (all_filter_check);
            filter_popover_box.append (native_filter_check);
            filter_popover_box.append (non_steam_filter_check);
            var filter_popover = new Gtk.Popover () {
                child = filter_popover_box
            };
            all_filter_check.toggled.connect (() => apply_filter_choice (
                all_filter_check, filter_popover
            ));
            native_filter_check.toggled.connect (() => apply_filter_choice (
                native_filter_check, filter_popover
            ));
            non_steam_filter_check.toggled.connect (() => apply_filter_choice (
                non_steam_filter_check, filter_popover
            ));
            filter_button = new Gtk.MenuButton () {
                valign = Gtk.Align.CENTER,
                icon_name = "filter-2-symbolic",
                popover = filter_popover,
                tooltip_text = _("Filter"),
                visible = false,
                css_classes = { "flat" }
            };
            Window.register_popover_for_controller (
                filter_popover, filter_button, all_filter_check
            );
            update_filter_button_state ();
        }

        void build_search_toolbar () {
            search_entry = new Gtk.SearchEntry () {
                placeholder_text = _("Search games"),
                hexpand = true
            };
            Utils.TextInputMetadataPolicy.apply (
                search_entry, Utils.TextInputFieldKind.SEARCH
            );
            search_entry.add_css_class ("flat");
            search_entry.changed.connect (schedule_search_filter);

            check_button = new Gtk.CheckButton () {
                tooltip_text = _("Select all visible games")
            };
            check_button.toggled.connect (() => {
                if (!updating_selection_toggle)
                    games.select_all_visible (check_button.get_active ());
            });
        }

        Gtk.Box build_toolbar () {
            var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                hexpand = true,
                overflow = Gtk.Overflow.HIDDEN
            };
            toolbar.add_css_class ("list-header");
            toolbar.append (check_button);
            toolbar.append (search_entry);
            toolbar.append (filter_button);
            return toolbar;
        }

        void apply_filter_choice (Gtk.CheckButton choice, Gtk.Popover popover) {
            if (!choice.active)
                return;
            refilter_games ();
            update_filter_button_state ();
            popover.popdown ();
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            this.launcher = launcher;
            filter_button.set_visible (launcher.has_library_support);
            non_steam_filter_check.set_visible (launcher is Models.Launchers.Steam);

            if (launcher.has_library_support) {
                if (invalid || error) {
                    show_normal ();
                    invalid = false;
                }
                if (launcher is Models.Launchers.Steam) {
                    var steam = (Models.Launchers.Steam) launcher;
                    if (!launcher.game_library_available || steam.profiles.length () == 0) {
                        error = true;
                        show_status_box (
                            "bug-symbolic",
                            _("Steam games couldn’t be loaded"),
                            _("Steam’s library or profile data is missing or invalid. Finish setting up Steam, then restart ProtonPlus. Tools and other launchers remain available.") // vala-lint=line-length
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
            games_card.set_visible (true);
            update_selection_controls ();
            status_page.set_visible (false);
        }

        void show_status_box (string icon, string title, string description,
            bool is_image = false) {
            games_card.set_visible (false);
            mass_edit_button.set_visible (false);
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
            cancel_focus_idle ();
            search_query = search_entry.get_text ().down ();
            overlay.add_overlay (spinner);

            compatibility_tool_model = new ListStore (
                typeof (Models.CompatibilityTool)
            );
            compatibility_tool_model.append (new Models.CompatibilityTool (
                _("Default"), "Default", "", Models.CompatibilityToolRuntimeKind.PROTON
            ));
            var steam = launcher as Models.Launchers.Steam;
            if (steam != null) {
                foreach (var tool in ((!) steam).get_assignable_compatibility_tools ())
                    compatibility_tool_model.append (tool);
            } else {
                foreach (var tool in launcher.compatibility_tools)
                    compatibility_tool_model.append (tool);
            }

            games.replace (launcher.games);
            refilter_games ();
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
                return Source.REMOVE;
            });
        }

        void refilter_games () {
            GameFilterMode mode = GameFilterMode.ALL;
            if (native_filter_check.active)
                mode = GameFilterMode.NATIVE;
            else if (non_steam_filter_check.active)
                mode = GameFilterMode.NON_STEAM;
            games.set_filter (search_query, mode);
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
            if (games.visible_count () > 0) {
                list_stack.set_visible_child_name ("list");
                return;
            }
            if (search_query.strip () != "") {
                empty_status_page.set_title (_("No matching games"));
                empty_status_page.set_description (
                    _("Try a different search term or clear the search.")
                );
                empty_status_page.set_icon_name ("magnifying-glass-symbolic");
            } else if (!all_filter_check.active) {
                empty_status_page.set_title (_("No games match this filter"));
                empty_status_page.set_description (
                    _("Choose All games to see your complete library.")
                );
                empty_status_page.set_icon_name ("filter-2-symbolic");
            } else {
                empty_status_page.set_title (_("No games found"));
                empty_status_page.set_description (
                    _("No games are available for this launcher.")
                );
                empty_status_page.set_icon_name ("gamepad-symbolic");
            }
            list_stack.set_visible_child_name ("empty");
        }

        void update_selection_controls () {
            var visible_count = games.visible_count ();
            var selected_count = games.selected_visible_count ();
            updating_selection_toggle = true;
            check_button.set_inconsistent (
                selected_count > 0 && selected_count < visible_count
            );
            check_button.set_active (
                visible_count > 0 && selected_count == visible_count
            );
            updating_selection_toggle = false;
            mass_edit_button.set_selected_count ((int) selected_count);
            mass_edit_button.set_visible (selected_count >= 2);
        }

        void open_single_game_edit (GameListItem item) {
            open_mass_edit ({ item });
        }

        void open_mass_edit (GameListItem[] items) {
            mass_edit_view.load (items, compatibility_tool_model, expression);
            selection_button.set_label (mass_edit_view.get_selection_text ());
            selection_button.set_visible (true);
            selection_popover_title.set_label (mass_edit_view.get_selection_text ());
            selection_list_box.remove_all ();
            foreach (var item in items) {
                var title = new Gtk.Label (item.game.name) {
                    halign = Gtk.Align.START,
                    hexpand = true,
                    xalign = 0,
                    ellipsize = Pango.EllipsizeMode.END
                };
                var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                content.add_css_class ("selection-popover-row");
                content.append (new Gtk.Image.from_icon_name ("gamepad-symbolic"));
                content.append (title);
                selection_list_box.append (new Gtk.ListBoxRow () {
                    activatable = false,
                    selectable = false,
                    focusable = false,
                    child = content
                });
            }
            mass_edit_cleanup_pending = true;
            push_mass_edit_page ();
        }

        void switch_collection_view (bool narrow) {
            var focused_item = find_focused_item ();
            if (focused_item != null)
                last_focused_item = focused_item;
            narrow_view_active = narrow;
            views_stack.set_visible_child_name (narrow ? "narrow" : "wide");
            if (focused_item != null) {
                var position = games.position_of ((!) focused_item);
                if (position >= 0)
                    schedule_item_focus ((uint) position, false);
            }
        }

        GameListItem? find_focused_item () {
            var focused = get_root ()?.get_focus ();
            if (focused == null)
                return null;
            foreach (var entry in narrow_rows.entries) {
                if (focused == entry.value || ((!) focused).is_ancestor (entry.value))
                    return entry.key;
            }
            foreach (var entry in wide_selection_cells.entries) {
                if (focused == entry.value || ((!) focused).is_ancestor (entry.value))
                    return entry.key;
            }
            foreach (var entry in wide_action_cells.entries) {
                if (focused == entry.value || ((!) focused).is_ancestor (entry.value))
                    return entry.key;
            }
            return null;
        }

        bool focus_narrow_relative (GameListItem item, int delta) {
            return focus_relative (item, delta, false);
        }

        bool focus_wide_relative (GameListItem item, int delta) {
            return focus_relative (item, delta, false);
        }

        bool focus_relative (GameListItem item, int delta, bool actions) {
            var position = games.position_of (item);
            if (position < 0)
                return false;
            var target = position + delta;
            if (target < 0)
                return search_entry.grab_focus ();
            if (target >= games.visible_count ())
                return delta > 0 && mass_edit_button.get_visible ()
                    && mass_edit_button.grab_focus ();
            last_focused_item = games.item_at ((uint) target);
            return focus_item ((uint) target, actions);
        }

        bool focus_wide_actions (GameListItem item) {
            var actions = wide_action_cells.get (item);
            if (actions != null)
                return ((!) actions).focus_first_action ();
            var position = games.position_of (item);
            return position >= 0 && focus_item ((uint) position, true);
        }

        bool focus_wide_selection (GameListItem item) {
            var cell = wide_selection_cells.get (item);
            return cell != null && ((!) cell).grab_focus ();
        }

        bool focus_item (uint position, bool actions) {
            var item = games.item_at (position);
            if (item == null)
                return false;
            if (narrow_view_active) {
                var row = narrow_rows.get ((!) item);
                if (row != null)
                    return ((!) row).grab_focus ();
                narrow_view.scroll_to (position, Gtk.ListScrollFlags.FOCUS, null);
            } else {
                if (actions) {
                    var action_cell = wide_action_cells.get ((!) item);
                    if (action_cell != null)
                        return ((!) action_cell).focus_first_action ();
                } else {
                    var selection_cell = wide_selection_cells.get ((!) item);
                    if (selection_cell != null)
                        return ((!) selection_cell).grab_focus ();
                }
                wide_view.scroll_to (
                    position, null, Gtk.ListScrollFlags.FOCUS, null
                );
            }
            schedule_item_focus (position, actions);
            return true;
        }

        void schedule_item_focus (uint position, bool actions) {
            cancel_focus_idle ();
            var expected_generation = games.generation;
            var expected_item = games.item_at (position);
            var expected_narrow = narrow_view_active;
            focus_idle_id = Idle.add (() => {
                focus_idle_id = 0;
                if (expected_item == null || games.generation != expected_generation ||
                    narrow_view_active != expected_narrow ||
                    games.item_at (position) != expected_item)
                    return Source.REMOVE;
                if (expected_narrow) {
                    var row = narrow_rows.get ((!) expected_item);
                    row?.grab_focus ();
                } else if (actions) {
                    var cell = wide_action_cells.get ((!) expected_item);
                    cell?.focus_first_action ();
                } else {
                    var cell = wide_selection_cells.get ((!) expected_item);
                    cell?.grab_focus ();
                }
                return Source.REMOVE;
            });
        }

        void cancel_focus_idle () {
            if (focus_idle_id == 0)
                return;
            Source.remove (focus_idle_id);
            focus_idle_id = 0;
        }

        bool focus_last_visible_game () {
            var count = games.visible_count ();
            return count > 0 && focus_item (count - 1, false);
        }

        public void show_games_list_page () {
            var cleanup_was_pending = mass_edit_cleanup_pending;
            if (navigation_view.get_visible_page () == mass_edit_page) {
                if (!pop_page ())
                    navigation_view.replace ({ list_page });
            } else {
                navigation_view.replace ({ list_page });
            }
            if (cleanup_was_pending)
                cleanup_mass_edit_exit ();
            else
                reset_games_list_state ();
        }

        void push_mass_edit_page () {
            if (navigation_view.get_visible_page () == mass_edit_page)
                return;
            var navigation_stack = navigation_view.get_navigation_stack ();
            for (uint i = 0; i < navigation_stack.get_n_items (); i++) {
                if (navigation_stack.get_item (i) == mass_edit_page) {
                    navigation_view.pop_to_page (mass_edit_page);
                    return;
                }
            }
            navigation_view.push (mass_edit_page);
        }

        bool pop_page () {
            return navigation_view.pop ();
        }

        void cleanup_mass_edit_exit () {
            if (!mass_edit_cleanup_pending)
                return;
            mass_edit_cleanup_pending = false;
            reset_games_list_state ();
        }

        void reset_games_list_state () {
            selection_popover.popdown ();
            selection_button.set_visible (false);
            search_entry.text = "";
            all_filter_check.active = true;
            games.clear_selection ();
            update_selection_controls ();
        }

        public string get_controller_page_id () {
            return "games:%s".printf (
                navigation_view.get_visible_page ().get_tag () ?? "list"
            );
        }

        public Header.Presentation? get_header_presentation () {
            if (navigation_view.get_visible_page () == mass_edit_page)
                return mass_edit_view.header_presentation;
            return null;
        }

        public Object? get_controller_page_root () {
            return navigation_view.get_visible_page ().get_child ();
        }

        public Object? get_controller_initial_focus () {
            if (navigation_view.get_visible_page () == mass_edit_page)
                return mass_edit_view.get_controller_initial_focus ();
            if (last_focused_item != null) {
                var position = games.position_of ((!) last_focused_item);
                if (position >= 0) {
                    focus_item ((uint) position, false);
                    if (narrow_view_active)
                        return narrow_rows.get ((!) last_focused_item);
                    return wide_selection_cells.get ((!) last_focused_item);
                }
            }
            var first = games.item_at (0);
            if (first == null)
                return null;
            if (narrow_view_active)
                return narrow_rows.get ((!) first);
            return wide_selection_cells.get ((!) first);
        }

        public bool controller_navigate_back () {
            return pop_page ();
        }

        public bool controller_can_navigate_back () {
            return navigation_view.get_visible_page () == mass_edit_page;
        }

        public bool controller_can_switch_page () {
            return false;
        }

        public bool controller_prefers_initial_focus_after_switch () {
            return false;
        }

        public bool controller_switch_page (int delta) {
            return false;
        }

        public bool controller_can_open_search () {
            return navigation_view.get_visible_page () == list_page &&
                search_entry.get_mapped () && search_entry.is_visible () &&
                search_entry.is_sensitive ();
        }

        public bool controller_can_open_filter () {
            return navigation_view.get_visible_page () == list_page &&
                filter_button.get_mapped () && filter_button.is_visible () &&
                filter_button.is_sensitive ();
        }

        public bool controller_open_search () {
            return controller_can_open_search () && search_entry.grab_focus ();
        }

        public bool controller_open_filter () {
            if (!controller_can_open_filter ())
                return false;
            filter_button.popup ();
            return true;
        }

        public override void dispose () {
            if (search_timeout_id != 0) {
                Source.remove (search_timeout_id);
                search_timeout_id = 0;
            }
            cancel_focus_idle ();
            base.dispose ();
        }
    }
}
