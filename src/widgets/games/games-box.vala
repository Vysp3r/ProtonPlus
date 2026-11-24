namespace ProtonPlus.Widgets.Games {
    public class Box : Gtk.Box, Utils.ControllerNavigationHost,
        Utils.ControllerPageShortcuts {
        const int NARROW_VIEW_WIDTH = 700;
        const int COMPACT_SELECTION_WIDTH = 490;

        Models.Launcher launcher;
        Models.Launchers.Steam? observed_steam;
        ulong steam_loading_handler;
        ulong steam_profile_handler;

        Gtk.Image image;
        Adw.StatusPage status_page;
        Gtk.Box status_actions;
        Gtk.Button retry_button;
        Gtk.Button copy_diagnostics_button;
        Gtk.Spinner status_spinner;
        MassEditButton mass_edit_button;
        Gtk.Box selection_footer;
        Gtk.Label selection_summary;
        Gtk.Button clear_selection_button;
        Gtk.SearchEntry search_entry;
        Gtk.CheckButton check_button;
        Gtk.Box toolbar;
        Adw.BreakpointBin games_card;
        Adw.NavigationView navigation_view;
        Adw.NavigationPage list_page;
        Adw.NavigationPage mass_edit_page;
        GameListView collection_view;
        Adw.StatusPage empty_status_page;
        Gtk.Button empty_action_button;
        GameListControllerBox games_controller_box;
        Gtk.MenuButton filter_button;
        Gtk.CheckButton all_filter_check;
        Gtk.CheckButton non_steam_filter_check;
        Gtk.CheckButton native_filter_check;
        MassEditView mass_edit_view;
        GameCollection games;
        ListStore compatibility_tool_model;
        Gtk.PropertyExpression expression;
        Gtk.MenuButton selection_button;
        Gtk.ListBox selection_list_box;
        Gtk.Popover selection_popover;
        Gtk.Label selection_popover_title;
        GameListItem? last_focused_item;
        string search_query = "";
        uint search_timeout_id = 0;
        uint edit_request;
        bool updating_selection_toggle = false;
        bool mass_edit_cleanup_pending = false;
        bool narrow_collection_view = false;

        public signal void header_presentation_changed (Header.Presentation? presentation);
        public signal void toast_sent (string title);

        construct {
            image = new Gtk.Image ();
            status_page = new Adw.StatusPage () {
                visible = false,
                vexpand = true,
                hexpand = true
            };
            build_status_actions ();

            games = new GameCollection ();
            collection_view = new GameListView (
                games, focus_relative, focus_wide_relative, activate_game_item
            );

            empty_status_page = new Adw.StatusPage () {
                title = _("No games found"),
                description = _("Try a different search term or filter."),
                icon_name = "edit-find-symbolic",
                vexpand = true,
                visible = false
            };
            empty_action_button = new Gtk.Button () {
                halign = Gtk.Align.CENTER,
                visible = false
            };
            empty_action_button.add_css_class ("suggested-action");
            empty_action_button.clicked.connect (() => {
                if (search_query.strip () != "") {
                    search_entry.set_text ("");
                    search_entry.grab_focus ();
                } else if (!all_filter_check.active) {
                    all_filter_check.active = true;
                    filter_button.grab_focus ();
                }
            });
            empty_status_page.set_child (empty_action_button);

            mass_edit_button = new MassEditButton (focus_before_selection_actions);
            mass_edit_button.mass_edit_requested.connect (() => {
                var selected = games.selected_items ();
                if (selected.length > 0)
                    open_mass_edit.begin ((owned) selected);
            });

            build_selection_popover ();
            var selection_content = build_selection_footer ();
            build_filter_popover ();
            build_search_toolbar ();
            games.state_changed.connect (() => {
                update_empty_state ();
                update_selection_controls ();
            });

            games_card = new Adw.BreakpointBin () {
                hexpand = true,
                vexpand = true,
                overflow = Gtk.Overflow.HIDDEN
            };
            games_card.set_size_request (360, 144);
            games_card.add_css_class ("card");
            toolbar = build_toolbar ();
            var games_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            games_content.append (toolbar);
            games_content.append (collection_view);
            games_content.append (empty_status_page);
            games_content.append (selection_footer);
            games_card.set_child (games_content);
            add_games_breakpoints (selection_content);

            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (0);

            games_controller_box = new GameListControllerBox (
                toolbar, collection_view.wide_view, collection_view.narrow_view,
                focus_games_toolbar, focus_first_visible_game,
                focus_first_visible_game_title
            ) {
                hexpand = true,
                vexpand = true
            };
            games_controller_box.append (games_card);
            games_controller_box.append (status_page);

            var games_page_clamp = new Adw.Clamp () {
                vexpand = true,
                maximum_size = 975,
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                child = games_controller_box
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

        void build_status_actions () {
            retry_button = new Gtk.Button.with_label (_("Retry")) {
                halign = Gtk.Align.CENTER,
                css_classes = { "pill", "suggested-action" }
            };
            retry_button.clicked.connect (() => {
                var steam = observed_steam;
                if (steam != null && !steam.game_library_available && !steam.game_library_loading)
                    steam.load_profile_library.begin ();
                else if (steam == null)
                    retry_launcher_library.begin ();
            });
            copy_diagnostics_button = new Gtk.Button.with_label (_("Copy Diagnostics")) {
                halign = Gtk.Align.CENTER
            };
            copy_diagnostics_button.clicked.connect (() => {
                var steam = observed_steam;
                if (steam == null || steam.game_library_issue == null)
                    return;
                get_clipboard ().set_text (steam.get_game_library_diagnostics ());
                toast_sent (_("Diagnostics copied"));
            });
            status_spinner = new Gtk.Spinner () {
                halign = Gtk.Align.CENTER
            };
            status_spinner.set_size_request (32, 32);
            status_spinner.bind_property ("visible", status_spinner, "spinning", BindingFlags.SYNC_CREATE);
            status_actions = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            status_actions.append (retry_button);
            status_actions.append (copy_diagnostics_button);
            status_actions.append (status_spinner);
            status_page.set_child (status_actions);
        }

        Gtk.Box build_selection_footer () {
            selection_summary = new Gtk.Label (null) {
                hexpand = true,
                xalign = 0,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                css_classes = { "heading" }
            };
            clear_selection_button = new Gtk.Button.with_label (_("Clear Selection")) {
                valign = Gtk.Align.CENTER
            };
            clear_selection_button.clicked.connect (() => {
                var had_focus = clear_selection_button.has_focus;
                games.clear_selection ();
                if (had_focus)
                    search_entry.grab_focus ();
            });
            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER
            };
            actions.append (clear_selection_button);
            actions.append (mass_edit_button);

            var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 12,
                margin_end = 12
            };
            content.append (selection_summary);
            content.append (actions);

            selection_footer = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { visible = false };
            selection_footer.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            selection_footer.append (content);
            return content;
        }

        void add_games_breakpoints (Gtk.Box selection_content) {
            var narrow = new Adw.Breakpoint (new Adw.BreakpointCondition.length (
                Adw.BreakpointConditionLengthType.MAX_WIDTH, NARROW_VIEW_WIDTH, Adw.LengthUnit.SP
            ));
            var compact = new Adw.Breakpoint (new Adw.BreakpointCondition.length (
                Adw.BreakpointConditionLengthType.MAX_WIDTH, COMPACT_SELECTION_WIDTH, Adw.LengthUnit.SP
            ));
            var vertical = Value (typeof (Gtk.Orientation));
            vertical.set_enum (Gtk.Orientation.VERTICAL);
            compact.add_setter (selection_content, "orientation", vertical);
            games_card.add_breakpoint ((owned) narrow);
            games_card.add_breakpoint ((owned) compact);
            games_card.notify["current-breakpoint"].connect (() => {
                switch_collection_view (games_card.get_current_breakpoint () != null);
            });
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
            filter_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Filter Games"), -1
            );
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
            search_entry.stop_search.connect (() => {
                if (search_entry.get_text () != "")
                    search_entry.set_text ("");
            });

            check_button = new Gtk.CheckButton () {
                tooltip_text = _("Select all visible games")
            };
            check_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Select all visible games"),
                -1
            );
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
            if (launcher == this.launcher)
                return;
            disconnect_steam_library ();
            show_games_list_page ();
            this.launcher = launcher;
            var steam_filters = launcher is Models.Launchers.Steam;
            filter_button.set_visible (steam_filters);
            non_steam_filter_check.set_visible (steam_filters);
            native_filter_check.set_visible (steam_filters);
            if (collection_view.set_prefix_visible (steam_filters))
                games_controller_box.reset_sort_header_configuration ();
            last_focused_item = null;

            observed_steam = launcher as Models.Launchers.Steam;
            if (observed_steam != null) {
                steam_loading_handler = observed_steam.notify["game-library-loading"].connect (refresh_launcher_page);
                steam_profile_handler = observed_steam.notify["profile"].connect (() => {
                    if (!((!) observed_steam).game_library_loading) {
                        show_games_list_page ();
                        refresh_launcher_page ();
                    }
                });
            }
            refresh_launcher_page ();
        }

        void disconnect_steam_library () {
            if (observed_steam == null)
                return;
            observed_steam.disconnect (steam_loading_handler);
            observed_steam.disconnect (steam_profile_handler);
            observed_steam = null;
        }

        void refresh_launcher_page () {
            if (launcher.has_library_support) {
                var steam = observed_steam;
                if (steam != null && (steam.game_library_loading || !steam.game_library_available)) {
                    show_steam_status (steam);
                } else if (!launcher.game_library_available) {
                    status_actions.set_visible (true);
                    retry_button.set_visible (true);
                    status_spinner.set_visible (false);
                    copy_diagnostics_button.set_visible (false);
                    show_status_box ("dialog-error-symbolic", _("Games couldn’t be loaded"), launcher.title);
                } else {
                    status_page.set_visible (false);
                    games_card.set_visible (true);
                    load_games ();
                }
            } else {
                status_actions.set_visible (false);
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
            header_presentation_changed (get_header_presentation ());
        }

        async void retry_launcher_library () {
            var requested = launcher;
            retry_button.set_visible (false);
            status_spinner.set_visible (true);
            yield requested.load_profile_library ();
            if (launcher == requested && get_root () != null)
                refresh_launcher_page ();
        }

        void show_steam_status (Models.Launchers.Steam steam) {
            bool loading = steam.game_library_loading;
            var installation = _("Steam (%s)").printf (steam.get_installation_type_title ());
            var issue = steam.game_library_issue;
            status_actions.set_visible (true);
            status_spinner.set_visible (loading);
            retry_button.set_visible (!loading);
            copy_diagnostics_button.set_visible (!loading && issue != null);
            show_status_box (
                loading ? "input-gaming-symbolic" : "dialog-error-symbolic",
                loading ? _("Loading Steam games") : _("Steam games couldn’t be loaded"),
                issue != null ? "%s\n%s".printf (installation, issue.describe ()) : installation
            );
        }

        void show_status_box (string icon, string title, string description,
            bool is_image = false) {
            games_card.set_visible (false);
            selection_footer.set_visible (false);
            if (is_image) {
                image.set_from_resource (icon);
                status_page.set_paintable (image.get_paintable ());
            } else {
                status_page.set_icon_name (icon);
            }
            status_page.set_title (title);
            status_page.set_description (Markup.escape_text (description));
            status_page.set_visible (true);
        }

        void load_games () {
            if (search_timeout_id != 0) {
                Source.remove (search_timeout_id);
                search_timeout_id = 0;
            }
            collection_view.cancel_focus ();
            search_query = search_entry.get_text ().down ();

            load_compatibility_tools ();
            games.replace (launcher.games);
            refilter_games ();
        }

        void load_compatibility_tools () {
            compatibility_tool_model = new ListStore (
                typeof (Models.CompatibilityTool)
            );
            compatibility_tool_model.append (new Models.CompatibilityTool (
                launcher.get_default_game_tool_title (), "Default", "", Models.CompatibilityToolRuntimeKind.PROTON
            ));
            var steam = launcher as Models.Launchers.Steam;
            if (steam != null) {
                foreach (var tool in ((!) steam).get_assignable_compatibility_tools ())
                    compatibility_tool_model.append (tool);
            } else {
                foreach (var tool in launcher.compatibility_tools)
                    compatibility_tool_model.append (tool);
            }
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
            var empty = games.visible_count () == 0;
            collection_view.set_empty (empty);
            empty_status_page.set_visible (empty);
            if (!empty)
                return;
            if (search_query.strip () != "") {
                empty_status_page.set_title (_("No matching games"));
                empty_status_page.set_description (
                    _("Try a different search term or clear the search.")
                );
                empty_status_page.set_icon_name ("edit-find-symbolic");
                empty_action_button.set_label (_("Clear Search"));
                empty_action_button.set_visible (true);
            } else if (!all_filter_check.active) {
                empty_status_page.set_title (_("No games match this filter"));
                empty_status_page.set_description (
                    _("Choose All games to see your complete library.")
                );
                empty_status_page.set_icon_name ("filter-2-symbolic");
                empty_action_button.set_label (_("Reset Filters"));
                empty_action_button.set_visible (true);
            } else {
                empty_status_page.set_title (_("No games found"));
                empty_status_page.set_description (
                    _("No games are available for this launcher.")
                );
                empty_status_page.set_icon_name ("input-gaming-symbolic");
                empty_action_button.set_visible (false);
            }
        }

        void update_selection_controls () {
            var visible_count = games.visible_count ();
            var selected_visible_count = games.selected_visible_count ();
            var selected_count = games.selected_count ();
            var hidden_count = selected_count - selected_visible_count;
            collection_view.set_selection_mode (selected_count > 0);
            updating_selection_toggle = true;
            check_button.set_inconsistent (
                selected_visible_count > 0 &&
                    selected_visible_count < visible_count
            );
            check_button.set_active (
                visible_count > 0 &&
                    selected_visible_count == visible_count
            );
            check_button.set_sensitive (visible_count > 0);
            updating_selection_toggle = false;
            var count_text = ngettext ("%u game selected", "%u games selected", selected_count)
                .printf (selected_count);
            selection_summary.set_label (hidden_count > 0
                ? _("%s · %u hidden by search or filters").printf (count_text, hidden_count)
                : count_text);
            bool show_actions = selected_count > 0 && games_card.get_visible ();
            selection_footer.set_visible (show_actions);
            if (show_actions) {
                mass_edit_button.set_selected_count ((int) selected_count);
                empty_action_button.remove_css_class ("suggested-action");
            } else {
                empty_action_button.add_css_class ("suggested-action");
            }
        }

        void activate_game_item (GameListItem item) {
            switch (GameActionAvailability.row_activation (collection_view.selection_mode_active)) {
            case GameRowActivation.TOGGLE_SELECTION:
                item.selected = !item.selected;
                break;
            case GameRowActivation.MODIFY:
                open_single_game_edit (item);
                break;
            }
        }

        void open_single_game_edit (GameListItem item) {
            open_mass_edit.begin ({ item });
        }

        async void open_mass_edit (owned GameListItem[] items) {
            var request = ++edit_request;
            var selected_launcher = launcher;
            var generation = games.generation;
            var tools_refreshed = yield selected_launcher.refresh_game_compatibility_tools ();
            if (request != edit_request || launcher != selected_launcher || generation != games.generation ||
                navigation_view.get_visible_page () != list_page || !get_mapped ())
                return;
            if (tools_refreshed) {
                load_compatibility_tools ();
                for (uint index = 0; index < games.store.get_n_items (); index++)
                    ((GameListItem) games.store.get_item (index)).refresh_tool_title ();
            }
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
                content.append (new Gtk.Image.from_icon_name ("input-gaming-symbolic"));
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
            if (narrow_collection_view == narrow)
                return;
            narrow_collection_view = narrow;
            var focused_item = collection_view.show_narrow (narrow);
            if (focused_item != null)
                last_focused_item = focused_item;
        }

        bool focus_wide_relative (GameListItem item, int delta,
            GameFocusLane lane) {
            if (delta < 0 &&
                GameControllerNavigationPolicy.top_boundary_uses_sort_header (
                    lane
                ) &&
                games.position_of (item) == 0 &&
                games_controller_box.focus_first_sort_header ())
                return true;
            return focus_relative (item, delta, lane);
        }

        bool focus_relative (GameListItem item, int delta, GameFocusLane lane) {
            var position = games.position_of (item);
            if (position < 0)
                return false;
            var target = position + delta;
            if (target < 0) {
                if (GameControllerNavigationPolicy.top_boundary_uses_selection (lane))
                    return check_button.grab_focus ();
                return search_entry.grab_focus ();
            }
            if (target >= games.visible_count ()) {
                if (delta <= 0)
                    return false;
                if (selection_footer.get_visible () && clear_selection_button.grab_focus ())
                    return true;
                return focus_launcher_selector ();
            }
            last_focused_item = games.item_at ((uint) target);
            return collection_view.focus_item ((uint) target, lane);
        }

        bool focus_launcher_selector () {
            var window = get_root () as Window;
            return window != null && ((!) window).focus_launcher_selector ();
        }

        bool focus_before_selection_actions () {
            var visible_count = games.visible_count ();
            if (visible_count > 0)
                return collection_view.focus_item (visible_count - 1, GameFocusLane.SELECTION);
            if (empty_action_button.visible && empty_action_button.grab_focus ())
                return true;
            return search_entry.grab_focus ();
        }

        bool focus_first_visible_game () {
            return focus_first_game_or_empty_action (GameFocusLane.SELECTION);
        }

        bool focus_first_visible_game_title () {
            return focus_first_game_or_empty_action (GameFocusLane.ROW);
        }

        bool focus_first_game_or_empty_action (GameFocusLane lane) {
            if (games.visible_count () > 0)
                return collection_view.focus_item (0, lane);
            return empty_action_button.get_mapped () && empty_action_button.grab_focus ();
        }

        bool focus_games_toolbar () {
            return search_entry.grab_focus ();
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
            edit_request++;
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
            if (status_page.get_visible ())
                return status_actions.visible && retry_button.visible ? retry_button : null;
            if (last_focused_item != null) {
                var position = games.position_of ((!) last_focused_item);
                if (position >= 0) {
                    collection_view.focus_item ((uint) position, GameFocusLane.SELECTION);
                    return collection_view.get_selection_target ((!) last_focused_item);
                }
            }
            var first = games.item_at (0);
            if (first == null) {
                if (selection_footer.visible)
                    return mass_edit_button;
                return empty_action_button.visible ? empty_action_button : null;
            }
            return collection_view.get_selection_target ((!) first);
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

        public bool search_available () {
            return navigation_view.get_visible_page () == list_page &&
                games_card.is_visible () && search_entry.is_sensitive ();
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
            disconnect_steam_library ();
            if (search_timeout_id != 0) {
                Source.remove (search_timeout_id);
                search_timeout_id = 0;
            }
            collection_view.detach ();
            base.dispose ();
        }
    }
}
