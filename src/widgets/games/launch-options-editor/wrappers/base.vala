using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public abstract class Base : Object, ILaunchOption {
        protected unowned LaunchOptionsList launch_option_handlers;
        protected unowned LaunchOptionPresentationRegistry? presentation_registry;
        LaunchOptionCatalog catalog;
        public signal void changed ();
        public bool is_advanced { get; set; }
        public LaunchLineType line_type { get; set; }
        protected Gee.List<ILaunchOption> _children;

        public bool active { get; set; }
        protected virtual string backend_id { get { return ""; } }

        protected Base (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            this.launch_option_handlers = launch_option_handlers;
            this.presentation_registry = presentation_registry;
            catalog = presentation_registry != null
                ? presentation_registry.catalog : new LaunchOptionCatalog ();
            this.line_type = LaunchLineType.WRAPPER;
            this._children = new Gee.ArrayList<ILaunchOption> ();
            this.is_advanced = false;
            this.launch_option_handlers.add (this);
            this.active = false;
        }

        internal LaunchOptionTile create_tile (string id, bool is_advanced = false) {
            var metadata = catalog.lookup (id);
            assert (metadata != null);
            var tile = new LaunchOptionTile (
                metadata.title, metadata.description, metadata.raw_tokens,
                is_advanced, metadata.serialization_type
            );
            tile.toggle.notify["active"].connect (() => {
                this.changed ();
            });

            this.add_child (tile);
            if (presentation_registry != null)
                presentation_registry.register (id, tile, tile, false);

            return tile;
        }

        protected void register_option (string id, Gtk.Widget widget, ILaunchOption? option = null) {
            if (presentation_registry != null)
                presentation_registry.register (id, widget, option, false);
        }

        internal void load_from_parse_result (LaunchCommandParseResult parsed, string[] tokens, bool[] consumed) {
            if (backend_id == "") {
                parse_tokens (tokens, consumed);
                return;
            }

            active = false;
            foreach (var invocation in parsed.wrappers) {
                if (invocation.wrapper_id != backend_id)
                    continue;

                var owned_indexes = new Gee.HashSet<int> ();
                foreach (var index in invocation.executable_indexes)
                    owned_indexes.add (index);
                owned_indexes.add_all (invocation.argument_indexes);
                if (invocation.delimiter_index >= 0)
                    owned_indexes.add (invocation.delimiter_index);
                foreach (var occurrence in parsed.occurrences) {
                    if (occurrence.wrapper_id == backend_id && occurrence.semantic_kind == LaunchOptionSemanticKind.COMPOSITE_DYNAMIC)
                        foreach (var index in occurrence.token_indexes)
                            owned_indexes.add (index);
                }

                var backend_tokens = new Gee.ArrayList<string> ();
                for (var index = 0; index < tokens.length; index++) {
                    if (owned_indexes.contains (index)) {
                        backend_tokens.add (tokens[index]);
                        consumed[index] = true;
                    }
                }
                parse_tokens (backend_tokens.to_array (), new bool[backend_tokens.size]);
                break;
            }
        }

        internal int get_wrapper_end_index (string[] tokens, int wrapper_index, bool[] consumed) {
            var last = tokens.length - 1;
            if (last > wrapper_index && tokens[last] == "--") {
                consumed[last] = true;
                return last;
            }
            return tokens.length;
        }

        internal int get_first_present_index (string[] tokens, string[] candidates) {
            for (var index = 0; index < tokens.length; index++) {
                foreach (var candidate in candidates) {
                    if (tokens[index] == candidate)
                        return index;
                }
            }

            return -1;
        }

        public void add_child (ILaunchOption child) {
            this._children.add (child);
        }

        public abstract void parse_tokens (string[] tokens, bool[] consumed);
        public abstract void clear ();
        public abstract void append_command_segments (Gee.LinkedList<string> segments);

        public bool is_active () {
            return this.active;
        }
    }
}
