namespace ProtonPlus.Widgets.Games {
    // Owns the concrete list widgets, their recycled cells and deferred focus.
    // GameCollection remains the owner of filtering, sorting and selection.
    public class GameListView : Gtk.Box {
        const int FOCUS_BIND_MAX_ATTEMPTS = 8;

        public Gtk.ColumnView wide_view { get; private set; }
        public Gtk.ListView narrow_view { get; private set; }
        public bool selection_mode_active { get; private set; default = false; }

        GameCollection games;
        Gtk.Stack views_stack;
        Gtk.ColumnViewColumn actions_column;
        Gee.HashMap<GameListItem, GameRow> narrow_rows;
        Gee.HashMap<GameListItem, GameSelectionCell> wide_selection_cells;
        Gee.HashMap<GameListItem, GameTitleCell> wide_title_cells;
        Gee.HashMap<GameListItem, GameActions> wide_action_cells;
        unowned GameVerticalFocusRequest focus_narrow_relative;
        unowned GameVerticalFocusRequest focus_wide_relative;
        unowned GameActivationRequest activate_game_item;
        bool narrow_view_active = false;
        uint focus_idle_id = 0;
        ulong wide_activation_handler = 0;
        ulong narrow_activation_handler = 0;

        public GameListView (GameCollection games,
            GameVerticalFocusRequest narrow_relative,
            GameVerticalFocusRequest wide_relative,
            GameActivationRequest activate_item) {
            Object (orientation: Gtk.Orientation.VERTICAL,
                hexpand: true, vexpand: true);
            this.games = games;
            focus_narrow_relative = narrow_relative;
            focus_wide_relative = wide_relative;
            activate_game_item = activate_item;
            narrow_rows = new Gee.HashMap<GameListItem, GameRow> ();
            wide_selection_cells = new Gee.HashMap<GameListItem, GameSelectionCell> ();
            wide_title_cells = new Gee.HashMap<GameListItem, GameTitleCell> ();
            wide_action_cells = new Gee.HashMap<GameListItem, GameActions> ();
            wide_view = build_wide_view ();
            narrow_view = build_narrow_view ();
            views_stack = new Gtk.Stack () {
                hexpand = true,
                vexpand = true,
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                transition_duration = 150
            };
            views_stack.add_named (create_collection_scroller (wide_view), "wide");
            views_stack.add_named (create_collection_scroller (narrow_view), "narrow");
            views_stack.set_visible_child_name ("wide");
            append (views_stack);
        }

        public GameListItem? show_narrow (bool narrow) {
            var focused_item = find_focused_item ();
            narrow_view_active = narrow;
            views_stack.set_visible_child_name (narrow ? "narrow" : "wide");
            if (focused_item != null) {
                var position = games.position_of ((!) focused_item);
                if (position >= 0)
                    schedule_item_focus ((uint) position, GameFocusLane.SELECTION);
            }
            return focused_item;
        }

        public Gtk.Widget? get_selection_target (GameListItem item) {
            if (narrow_view_active)
                return narrow_rows.get (item);
            return wide_selection_cells.get (item);
        }

        Gtk.ColumnView build_wide_view () {
            var view = new Gtk.ColumnView (games.selection_model) {
                hexpand = true,
                vexpand = true,
                show_column_separators = false,
                show_row_separators = true,
                single_click_activate = true
            };
            view.add_css_class ("list-content");
            wide_activation_handler = view.activate.connect (activate_game_row);

            var selection_column = new Gtk.ColumnViewColumn (
                "", create_selection_factory ()
            );
            selection_column.set_expand (false);
            view.append_column (selection_column);

            var title_column = new Gtk.ColumnViewColumn (
                _("Game"), create_title_factory ()
            );
            title_column.set_expand (false);
            title_column.set_sorter (games.name_sorter);
            view.append_column (title_column);

            var prefix_column = new Gtk.ColumnViewColumn (
                _("Prefix"), create_text_factory (GameTextCellKind.PREFIX)
            );
            prefix_column.set_expand (false);
            prefix_column.set_sorter (games.prefix_sorter);
            view.append_column (prefix_column);

            var tool_column = new Gtk.ColumnViewColumn (
                _("Tool"), create_text_factory (GameTextCellKind.TOOL)
            );
            tool_column.set_expand (true);
            tool_column.set_sorter (games.tool_sorter);
            view.append_column (tool_column);

            actions_column = new Gtk.ColumnViewColumn (
                _("Actions"), create_actions_factory ()
            );
            actions_column.set_expand (false);
            view.append_column (actions_column);

            view.sort_by_column (title_column, Gtk.SortType.ASCENDING);
            var view_sorter = view.get_sorter ();
            if (view_sorter != null)
                games.set_sorter ((!) view_sorter);
            return view;
        }

        Gtk.ListView build_narrow_view () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var row = new GameRow (
                    focus_narrow_relative, activate_game_item
                );
                list_item.set_activatable (true);
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
                ((!) row).set_selection_mode (selection_mode_active);
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
                single_click_activate = true
            };
            view.add_css_class ("boxed-list");
            view.add_css_class ("list-content");
            narrow_activation_handler = view.activate.connect (activate_game_row);
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
                list_item.set_activatable (true);
                list_item.set_focusable (false);
                list_item.set_selectable (false);
                list_item.set_child (new GameSelectionCell (
                    focus_wide_relative, focus_wide_title
                ));
            });
            factory.bind.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var item = list_item.get_item () as GameListItem;
                var cell = list_item.get_child () as GameSelectionCell;
                if (item == null || cell == null)
                    return;
                ((!) cell).bind ((!) item);
                ((!) cell).set_selection_mode (selection_mode_active);
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

        Gtk.SignalListItemFactory create_title_factory () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                list_item.set_activatable (true);
                list_item.set_focusable (false);
                list_item.set_selectable (false);
                list_item.set_child (new GameTitleCell (
                    focus_wide_relative, focus_wide_selection,
                    focus_wide_actions, activate_game_item
                ));
            });
            factory.bind.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var item = list_item.get_item () as GameListItem;
                var cell = list_item.get_child () as GameTitleCell;
                if (item == null || cell == null)
                    return;
                ((!) cell).bind ((!) item);
                ((!) cell).set_selection_mode (selection_mode_active);
                wide_title_cells.set ((!) item, (!) cell);
            });
            factory.unbind.connect ((object) => {
                var cell = ((Gtk.ListItem) object).get_child () as GameTitleCell;
                if (cell == null)
                    return;
                var item = ((!) cell).get_item ();
                if (item != null && wide_title_cells.get ((!) item) == cell)
                    wide_title_cells.unset ((!) item);
                ((!) cell).unbind ();
            });
            factory.teardown.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var cell = list_item.get_child () as GameTitleCell;
                cell?.unbind ();
                list_item.set_child (null);
            });
            return factory;
        }

        Gtk.SignalListItemFactory create_text_factory (GameTextCellKind kind) {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                list_item.set_activatable (true);
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
                list_item.set_activatable (true);
                list_item.set_focusable (false);
                list_item.set_selectable (false);
                list_item.set_child (new GameActions (
                    focus_wide_relative, focus_wide_title
                ));
            });
            factory.bind.connect ((object) => {
                var list_item = (Gtk.ListItem) object;
                var item = list_item.get_item () as GameListItem;
                var actions = list_item.get_child () as GameActions;
                if (item == null || actions == null)
                    return;
                ((!) actions).bind ((!) item);
                ((!) actions).set_selection_mode (selection_mode_active);
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

        public void set_selection_mode (bool active) {
            if (selection_mode_active == active)
                return;
            selection_mode_active = active;
            actions_column.set_visible (!active);
            foreach (var row in narrow_rows.values)
                row.set_selection_mode (active);
            foreach (var cell in wide_selection_cells.values)
                cell.set_selection_mode (active);
            foreach (var cell in wide_title_cells.values)
                cell.set_selection_mode (active);
            foreach (var actions in wide_action_cells.values)
                actions.set_selection_mode (active);
        }

        void activate_game_row (uint position) {
            var item = games.item_at (position);
            if (item == null)
                return;
            activate_game_item ((!) item);
        }

        public GameListItem? find_focused_item () {
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
            foreach (var entry in wide_title_cells.entries) {
                if (focused == entry.value || ((!) focused).is_ancestor (entry.value))
                    return entry.key;
            }
            foreach (var entry in wide_action_cells.entries) {
                if (focused == entry.value || ((!) focused).is_ancestor (entry.value))
                    return entry.key;
            }
            return null;
        }

        bool focus_wide_actions (GameListItem item) {
            var actions = wide_action_cells.get (item);
            if (actions != null)
                return ((!) actions).focus_first_action ();
            var position = games.position_of (item);
            return position >= 0 && focus_item (
                (uint) position, GameFocusLane.FIRST_ACTION
            );
        }

        bool focus_wide_title (GameListItem item) {
            if (selection_mode_active)
                return focus_wide_selection (item);
            var cell = wide_title_cells.get (item);
            if (cell != null)
                return ((!) cell).grab_focus ();
            var position = games.position_of (item);
            return position >= 0 && focus_item (
                (uint) position, GameFocusLane.ROW
            );
        }

        bool focus_wide_selection (GameListItem item) {
            var cell = wide_selection_cells.get (item);
            return cell != null && ((!) cell).grab_focus ();
        }

        public bool focus_item (uint position, GameFocusLane lane) {
            var item = games.item_at (position);
            if (item == null)
                return false;
            bool focus_ready;
            if (try_focus_bound_item (
                (!) item, lane, narrow_view_active, out focus_ready
            )) {
                scroll_collection_to (position, narrow_view_active);
                return true;
            }
            if (focus_ready)
                return false;
            schedule_item_focus (position, lane);
            return true;
        }

        bool try_focus_bound_item (GameListItem item, GameFocusLane lane,
            bool narrow, out bool focus_ready) {
            lane = GameControllerNavigationPolicy.selection_mode_lane (
                lane, selection_mode_active
            );
            if (narrow) {
                var row = narrow_rows.get (item);
                focus_ready = row != null && ((!) row).get_mapped ();
                return focus_ready && ((!) row).focus_lane (lane);
            }
            if (lane == GameFocusLane.ROW) {
                var cell = wide_title_cells.get (item);
                focus_ready = cell != null && ((!) cell).get_mapped ();
                return focus_ready && ((!) cell).grab_focus ();
            }
            if (lane != GameFocusLane.SELECTION) {
                var cell = wide_action_cells.get (item);
                focus_ready = cell != null && ((!) cell).get_mapped ();
                return focus_ready && ((!) cell).focus_lane (lane);
            }
            var cell = wide_selection_cells.get (item);
            focus_ready = cell != null && ((!) cell).get_mapped ();
            return focus_ready && ((!) cell).grab_focus ();
        }

        void scroll_collection_to (uint position, bool narrow) {
            if (narrow) {
                narrow_view.scroll_to (
                    position, Gtk.ListScrollFlags.NONE, null
                );
            } else {
                wide_view.scroll_to (
                    position, null, Gtk.ListScrollFlags.NONE, null
                );
            }
        }

        void schedule_item_focus (uint position, GameFocusLane lane) {
            cancel_focus ();
            var expected_generation = games.generation;
            var expected_item = games.item_at (position);
            if (expected_item == null)
                return;
            var expected_narrow = narrow_view_active;
            scroll_collection_to (position, expected_narrow);
            schedule_item_focus_attempt (
                position, lane, expected_generation, (!) expected_item,
                expected_narrow, 0
            );
        }

        void schedule_item_focus_attempt (uint position, GameFocusLane lane,
            uint64 expected_generation, GameListItem expected_item,
            bool expected_narrow, int attempt) {
            focus_idle_id = Timeout.add (attempt == 0 ? 1 : 16, () => {
                focus_idle_id = 0;
                if (games.generation != expected_generation ||
                    narrow_view_active != expected_narrow ||
                    games.item_at (position) != expected_item)
                    return Source.REMOVE;
                bool focus_ready;
                if (try_focus_bound_item (
                    expected_item, lane, expected_narrow, out focus_ready
                )) {
                    scroll_collection_to (position, expected_narrow);
                } else if (!focus_ready && attempt < FOCUS_BIND_MAX_ATTEMPTS) {
                    scroll_collection_to (position, expected_narrow);
                    schedule_item_focus_attempt (
                        position, lane, expected_generation, expected_item,
                        expected_narrow, attempt + 1
                    );
                }
                return Source.REMOVE;
            });
        }

        public void cancel_focus () {
            if (focus_idle_id == 0)
                return;
            Source.remove (focus_idle_id);
            focus_idle_id = 0;
        }

        // The page calls detach before releasing its children so factory
        // callbacks cannot retain the list or its page-navigation delegates.
        public void detach () {
            cancel_focus ();
            if (wide_activation_handler != 0) {
                wide_view.disconnect (wide_activation_handler);
                wide_activation_handler = 0;
            }
            if (narrow_activation_handler != 0) {
                narrow_view.disconnect (narrow_activation_handler);
                narrow_activation_handler = 0;
            }
            narrow_view.set_model (null);
            narrow_view.set_factory (null);
            wide_view.set_model (null);
            var columns = wide_view.get_columns ();
            for (uint i = 0; i < columns.get_n_items (); i++) {
                var column = columns.get_item (i) as Gtk.ColumnViewColumn;
                if (column != null)
                    ((!) column).set_factory (null);
            }
            foreach (var row in narrow_rows.values)
                row.unbind ();
            foreach (var cell in wide_selection_cells.values)
                cell.unbind ();
            foreach (var cell in wide_title_cells.values)
                cell.unbind ();
            foreach (var actions in wide_action_cells.values)
                actions.unbind ();
            narrow_rows.clear ();
            wide_selection_cells.clear ();
            wide_title_cells.clear ();
            wide_action_cells.clear ();
        }

        public override void dispose () {
            detach ();
            base.dispose ();
        }
    }
}
