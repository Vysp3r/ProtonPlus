namespace ProtonPlus.Widgets.Games {
    public enum GameFilterMode {
        ALL,
        NATIVE,
        NON_STEAM
    }

    public class GameListItem : Object {
        public Models.Game game { get; construct; }
        public string normalized_name { get; private set; }
        public bool is_native { get; private set; }
        public bool is_non_steam { get; private set; }
        public bool has_install_directory { get; private set; }
        public bool has_prefix_directory { get; private set; }
        public string tool_title { get; private set; }
        public bool selected { get; set; default = false; }

        ulong compatibility_tool_handler = 0;
        ulong native_handler = 0;

        public GameListItem (Models.Game game) {
            Object (game: game);

            normalized_name = game.name.down ();
            is_native = game.is_native;
            is_non_steam = game is Models.Games.Steam
                && ((Models.Games.Steam) game).is_non_steam;
            has_install_directory = FileUtils.test (
                game.installdir, FileTest.IS_DIR
            );
            has_prefix_directory = FileUtils.test (
                game.prefixdir, FileTest.IS_DIR
            );
            tool_title = resolve_tool_title ();

            compatibility_tool_handler = game.notify["compatibility-tool"].connect (
                refresh_tool_title
            );
            native_handler = game.notify["is-native"].connect (() => {
                is_native = game.is_native;
                notify_property ("is-native");
                refresh_tool_title ();
            });
        }

        public bool matches (string query, GameFilterMode mode) {
            if (!normalized_name.contains (query))
                return false;

            switch (mode) {
            case GameFilterMode.NATIVE:
                return is_native;
            case GameFilterMode.NON_STEAM:
                return is_non_steam;
            default:
                return true;
            }
        }

        public void refresh_tool_title () {
            var title = resolve_tool_title ();
            if (tool_title == title)
                return;
            tool_title = title;
            notify_property ("tool-title");
        }

        string resolve_tool_title () {
            if (game.compatibility_tool == "Default" && game.is_native)
                return _("Native");

            foreach (var tool in game.launcher.compatibility_tools) {
                if (tool.internal_title == game.compatibility_tool)
                    return tool.display_title;
            }
            return _("Default");
        }

        public override void dispose () {
            if (compatibility_tool_handler != 0) {
                game.disconnect (compatibility_tool_handler);
                compatibility_tool_handler = 0;
            }
            if (native_handler != 0) {
                game.disconnect (native_handler);
                native_handler = 0;
            }
            base.dispose ();
        }
    }

    public class GameCollection : Object {
        public ListStore store { get; private set; }
        public Gtk.FilterListModel filtered_model { get; private set; }
        public Gtk.SortListModel sorted_model { get; private set; }
        public Gtk.MultiSelection selection_model { get; private set; }
        public uint64 generation { get; private set; default = 0; }

        public signal void state_changed ();

        Gtk.CustomFilter filter;
        Gtk.CustomSorter sorter;
        Gee.HashMap<GameListItem, ulong> selection_handlers;
        string query = "";
        GameFilterMode filter_mode = GameFilterMode.ALL;

        public GameCollection () {
            store = new ListStore (typeof (GameListItem));
            filter = new Gtk.CustomFilter ((object) => {
                var item = object as GameListItem;
                return item != null && ((!) item).matches (query, filter_mode);
            });
            filtered_model = new Gtk.FilterListModel (store, filter);
            sorter = new Gtk.CustomSorter ((object_a, object_b) => {
                var a = (GameListItem) object_a;
                var b = (GameListItem) object_b;
                var result = strcmp (a.game.name, b.game.name);
                if (result < 0)
                    return Gtk.Ordering.SMALLER;
                if (result > 0)
                    return Gtk.Ordering.LARGER;
                return Gtk.Ordering.EQUAL;
            });
            sorted_model = new Gtk.SortListModel (filtered_model, sorter);
            selection_model = new Gtk.MultiSelection (sorted_model);
            selection_handlers = new Gee.HashMap<GameListItem, ulong> ();
        }

        public void replace (List<Models.Game> games) {
            foreach (var entry in selection_handlers.entries)
                entry.key.disconnect (entry.value);
            selection_handlers.clear ();
            selection_model.unselect_all ();
            store.remove_all ();

            foreach (var game in games) {
                var item = new GameListItem (game);
                var handler_id = item.notify["selected"].connect (() => {
                    sync_item_selection (item);
                    state_changed ();
                });
                selection_handlers.set (item, handler_id);
                store.append (item);
            }

            generation++;
            sync_visible_selection ();
            state_changed ();
        }

        public void set_filter (string query, GameFilterMode mode) {
            this.query = query;
            filter_mode = mode;
            filter.changed (Gtk.FilterChange.DIFFERENT);
            sync_visible_selection ();
            state_changed ();
        }

        public uint visible_count () {
            return sorted_model.get_n_items ();
        }

        public uint selected_visible_count () {
            uint count = 0;
            for (uint i = 0; i < sorted_model.get_n_items (); i++) {
                var item = sorted_model.get_item (i) as GameListItem;
                if (item != null && ((!) item).selected)
                    count++;
            }
            return count;
        }

        public GameListItem[] selected_items () {
            var selected = new Gee.ArrayList<GameListItem> ();
            for (uint i = 0; i < store.get_n_items (); i++) {
                var item = store.get_item (i) as GameListItem;
                if (item != null && ((!) item).selected)
                    selected.add ((!) item);
            }
            selected.sort ((a, b) => strcmp (a.game.name, b.game.name));
            return selected.to_array ();
        }

        public void select_all_visible (bool selected) {
            for (uint i = 0; i < sorted_model.get_n_items (); i++) {
                var item = sorted_model.get_item (i) as GameListItem;
                if (item != null)
                    ((!) item).selected = selected;
            }
            sync_visible_selection ();
            state_changed ();
        }

        public void clear_selection () {
            for (uint i = 0; i < store.get_n_items (); i++) {
                var item = store.get_item (i) as GameListItem;
                if (item != null)
                    ((!) item).selected = false;
            }
            selection_model.unselect_all ();
            state_changed ();
        }

        public int position_of (GameListItem expected) {
            for (uint i = 0; i < sorted_model.get_n_items (); i++) {
                if (sorted_model.get_item (i) == expected)
                    return (int) i;
            }
            return -1;
        }

        public GameListItem? item_at (uint position) {
            return sorted_model.get_item (position) as GameListItem;
        }

        void sync_item_selection (GameListItem item) {
            var position = position_of (item);
            if (position < 0)
                return;
            if (item.selected)
                selection_model.select_item ((uint) position, false);
            else
                selection_model.unselect_item ((uint) position);
        }

        void sync_visible_selection () {
            selection_model.unselect_all ();
            for (uint i = 0; i < sorted_model.get_n_items (); i++) {
                var item = sorted_model.get_item (i) as GameListItem;
                if (item != null && ((!) item).selected)
                    selection_model.select_item (i, false);
            }
        }

        public override void dispose () {
            foreach (var entry in selection_handlers.entries)
                entry.key.disconnect (entry.value);
            selection_handlers.clear ();
            base.dispose ();
        }
    }
}
