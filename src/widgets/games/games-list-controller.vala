namespace ProtonPlus.Widgets.Games {
    public delegate bool GameBoundaryFocusRequest ();

    class GameSortHeaderTarget : Object {
        weak Gtk.ColumnView? view;
        Gtk.ColumnViewColumn column;
        public Gtk.Widget header { get; private set; }
        public Gtk.Button activation_target { get; private set; }
        ulong activation_handler;

        public GameSortHeaderTarget (Gtk.ColumnView view,
            Gtk.ColumnViewColumn column, Gtk.Widget header) {
            this.view = view;
            this.column = column;
            this.header = header;

            activation_target = new Gtk.Button ();
            activation_handler = activation_target.activate.connect (activate_sort);
        }

        public void set_controller_focus (bool focused) {
            if (focused)
                header.add_css_class ("games-sort-header-controller-focus");
            else
                header.remove_css_class ("games-sort-header-controller-focus");
        }

        public string get_title () {
            return column.get_title () ?? "";
        }

        void activate_sort () {
            if (view == null)
                return;
            var sorter = ((!) view).get_sorter () as Gtk.ColumnViewSorter;
            var is_primary = sorter != null &&
                ((!) sorter).get_primary_sort_column () == column;
            var current_direction = sorter != null
                ? ((!) sorter).get_primary_sort_order ()
                : Gtk.SortType.ASCENDING;
            if (!is_primary)
                ((!) view).sort_by_column (null, Gtk.SortType.ASCENDING);
            ((!) view).sort_by_column (
                column,
                GameControllerNavigationPolicy.next_sort_direction (
                    is_primary, current_direction
                )
            );
        }

        public void detach () {
            if (activation_handler != 0) {
                activation_target.disconnect (activation_handler);
                activation_handler = 0;
            }
            set_controller_focus (false);
            view = null;
        }
    }

    class GameSortHeaderMapTarget : Object {
        weak GameListControllerBox? owner;

        public GameSortHeaderMapTarget (GameListControllerBox owner) {
            this.owner = owner;
        }

        public void mapped () {
            if (owner != null)
                ((!) owner).begin_sort_header_configuration ();
        }
    }

    class GameListControllerBox : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationRedirect {
        const int SORT_HEADER_BIND_MAX_ATTEMPTS = 8;

        Gtk.Widget toolbar;
        Gtk.ColumnView wide_view;
        Gtk.Widget narrow_view;
        unowned GameBoundaryFocusRequest toolbar_focus;
        unowned GameBoundaryFocusRequest first_game_focus;
        unowned GameBoundaryFocusRequest first_game_title_focus;
        Gee.ArrayList<GameSortHeaderTarget> sort_headers;
        GameSortHeaderMapTarget sort_header_map_target;
        ulong sort_header_map_handler;
        uint sort_header_idle_id = 0;
        int sort_header_attempt = 0;
        int active_sort_header_index = -1;

        public GameListControllerBox (Gtk.Widget toolbar, Gtk.ColumnView wide_view,
            Gtk.Widget narrow_view, GameBoundaryFocusRequest toolbar_focus,
            GameBoundaryFocusRequest first_game_focus,
            GameBoundaryFocusRequest first_game_title_focus) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            this.toolbar = toolbar;
            this.wide_view = wide_view;
            this.narrow_view = narrow_view;
            this.toolbar_focus = toolbar_focus;
            this.first_game_focus = first_game_focus;
            this.first_game_title_focus = first_game_title_focus;
            set_focusable (true);
            add_css_class ("games-sort-header-focus-proxy");
            sort_headers = new Gee.ArrayList<GameSortHeaderTarget> ();
            sort_header_map_target = new GameSortHeaderMapTarget (this);
            sort_header_map_handler = wide_view.map.connect (
                sort_header_map_target.mapped
            );
            notify["has-focus"].connect (() => {
                if (!has_focus)
                    clear_sort_header_focus ();
            });
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;

            var sort_header_index = focused == this
                ? active_sort_header_index
                : -1;
            if (sort_header_index >= 0) {
                var header_action =
                    GameControllerNavigationPolicy.sort_header_action (
                        sort_header_index, sort_headers.size, direction
                    );
                switch (header_action) {
                case GameSortHeaderNavigationAction.PREVIOUS_HEADER:
                    return focus_sort_header (sort_header_index - 1);
                case GameSortHeaderNavigationAction.NEXT_HEADER:
                    return focus_sort_header (sort_header_index + 1);
                case GameSortHeaderNavigationAction.FOCUS_TOOLBAR:
                    return toolbar_focus ();
                case GameSortHeaderNavigationAction.FOCUS_FIRST_GAME:
                    return first_game_title_focus ();
                default:
                    return false;
                }
            }

            var action = GameControllerNavigationPolicy.boundary_action (
                is_inside_widget ((!) focused, toolbar),
                is_inside_widget ((!) focused, wide_view) ||
                    is_inside_widget ((!) focused, narrow_view),
                direction,
                wide_view.get_mapped ()
            );
            switch (action) {
            case GameCollectionBoundaryAction.FOCUS_TOOLBAR:
                return toolbar_focus ();
            case GameCollectionBoundaryAction.FOCUS_FIRST_SORT_HEADER:
                if (focus_first_sort_header ())
                    return true;
                return first_game_focus ();
            case GameCollectionBoundaryAction.FOCUS_FIRST_GAME:
                return first_game_focus ();
            default:
                return false;
            }
        }

        public Object? get_controller_activation_target (Object focused_object) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return null;
            var index = focused == this ? active_sort_header_index : -1;
            if (index < 0)
                return null;
            return sort_headers[index].activation_target;
        }

        public bool focus_first_sort_header () {
            configure_sort_headers ();
            return focus_sort_header (0);
        }

        public void begin_sort_header_configuration () {
            sort_header_attempt = 0;
            configure_sort_headers ();
        }

        void configure_sort_headers () {
            if (!wide_view.get_mapped () || sort_headers.size > 0)
                return;

            var headers = new Gee.ArrayList<Gtk.Widget> ();
            collect_column_headers (wide_view, headers);
            var columns = wide_view.get_columns ();
            if (headers.size < columns.get_n_items ()) {
                if (sort_header_attempt < SORT_HEADER_BIND_MAX_ATTEMPTS) {
                    sort_header_attempt++;
                    schedule_sort_header_configuration ();
                }
                return;
            }

            for (uint i = 0; i < columns.get_n_items (); i++) {
                var column = columns.get_item (i) as Gtk.ColumnViewColumn;
                if (column == null || ((!) column).get_sorter () == null)
                    continue;
                var header = headers[(int) i];
                sort_headers.add (new GameSortHeaderTarget (
                    wide_view, (!) column, header
                ));
            }
        }

        void schedule_sort_header_configuration () {
            if (sort_header_idle_id != 0)
                return;
            weak GameListControllerBox weak_self = this;
            sort_header_idle_id = Idle.add (() => {
                if (weak_self == null)
                    return Source.REMOVE;
                ((!) weak_self).sort_header_idle_id = 0;
                ((!) weak_self).configure_sort_headers ();
                return Source.REMOVE;
            });
        }

        void collect_column_headers (Gtk.Widget parent,
            Gee.ArrayList<Gtk.Widget> headers) {
            var child = parent.get_first_child ();
            while (child != null) {
                if (((Gtk.Accessible) child).get_accessible_role () ==
                    Gtk.AccessibleRole.COLUMN_HEADER) {
                    headers.add (child);
                } else {
                    collect_column_headers (child, headers);
                }
                child = child.get_next_sibling ();
            }
        }

        bool focus_sort_header (int index) {
            if (index < 0 || index >= sort_headers.size)
                return false;
            clear_sort_header_focus ();
            active_sort_header_index = index;
            sort_headers[index].set_controller_focus (true);
            update_property (
                Gtk.AccessibleProperty.LABEL,
                sort_headers[index].get_title (),
                -1
            );
            if (grab_focus ())
                return true;
            clear_sort_header_focus ();
            return false;
        }

        void clear_sort_header_focus () {
            if (active_sort_header_index >= 0 &&
                active_sort_header_index < sort_headers.size) {
                sort_headers[active_sort_header_index].set_controller_focus (
                    false
                );
            }
            active_sort_header_index = -1;
            reset_property (Gtk.AccessibleProperty.LABEL);
        }

        bool is_inside_widget (Gtk.Widget focused, Gtk.Widget ancestor) {
            return focused == ancestor || focused.is_ancestor (ancestor);
        }

        public override void dispose () {
            clear_sort_header_focus ();
            if (sort_header_idle_id != 0) {
                Source.remove (sort_header_idle_id);
                sort_header_idle_id = 0;
            }
            if (sort_header_map_handler != 0) {
                wide_view.disconnect (sort_header_map_handler);
                sort_header_map_handler = 0;
            }
            foreach (var target in sort_headers)
                target.detach ();
            sort_headers.clear ();
            base.dispose ();
        }
    }

}
