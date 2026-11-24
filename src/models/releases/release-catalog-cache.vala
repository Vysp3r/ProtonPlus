namespace ProtonPlus.Models {
    // A persisted browse-state snapshot.  It deliberately contains canonical
    // Release objects rather than an intermediate release representation.
    public class ReleaseCatalogSnapshot : Object {
        public Gee.LinkedList<Release> releases { get; construct; }
        public int page { get; construct; }
        public bool has_more { get; construct; }
        public string last_updated { get; construct; }

        public ReleaseCatalogSnapshot (
            Gee.LinkedList<Release> releases,
            int page,
            bool has_more,
            string last_updated
        ) {
            Object (
                releases: releases,
                page: page,
                has_more: has_more,
                last_updated: last_updated
            );
        }
    }

    // Release serialization belongs to the catalog that owns the state, not
    // to the shared cache-directory lifecycle coordinator.
    public class ReleaseCatalogCache : Object {
        private string tool_id;
        private string tool_title;

        public ReleaseCatalogCache (string tool_id, string tool_title) {
            this.tool_id = tool_id;
            this.tool_title = tool_title;
        }

        public async void save (ReleaseCatalogSnapshot snapshot) {
            var root_obj = new Json.Object ();
            root_obj.set_string_member ("last_updated", snapshot.last_updated);
            root_obj.set_int_member ("page", snapshot.page);
            root_obj.set_boolean_member ("has_more", snapshot.has_more);

            var releases_array = new Json.Array ();
            foreach (var release in snapshot.releases)
                releases_array.add_object_element (release.to_json ());
            root_obj.set_array_member ("releases", releases_array);

            var generator = new Json.Generator ();
            var root_node = new Json.Node (Json.NodeType.OBJECT);
            root_node.set_object (root_obj);
            generator.set_root (root_node);

            if (Utils.Filesystem.modify_file (get_cache_file (), generator.to_data (null)))
                Utils.Filesystem.delete_file (get_legacy_cache_file ());
        }

        public async ReleaseCatalogSnapshot? load () {
            var cache_file = get_cache_file ();
            var legacy_cache_file = get_legacy_cache_file ();
            var loading_legacy_cache = false;

            if (!FileUtils.test (cache_file, FileTest.EXISTS)) {
                if (!FileUtils.test (legacy_cache_file, FileTest.EXISTS))
                    return null;

                cache_file = legacy_cache_file;
                loading_legacy_cache = true;
            }

            var json = Utils.Filesystem.get_file_content (cache_file);
            if (json == "")
                return null;

            var root_node = parse_cache_json (json);
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT)
                return null;

            var root_obj = root_node.get_object ();
            if (!root_obj.has_member ("releases"))
                return null;
            var releases_node = root_obj.get_member ("releases");
            if (releases_node == null || releases_node.get_node_type () != Json.NodeType.ARRAY)
                return null;

            var releases = new Gee.LinkedList<Release> ();
            var releases_array = releases_node.get_array ();
            for (var i = 0; i < releases_array.get_length (); i++) {
                var release_obj = releases_array.get_object_element (i);
                if (release_obj == null)
                    continue;
                var release = Release.from_json (release_obj);
                if (release != null)
                    releases.add (release);
            }

            if (loading_legacy_cache) {
                if (Utils.Filesystem.modify_file (get_cache_file (), json))
                    Utils.Filesystem.delete_file (legacy_cache_file);
            } else if (FileUtils.test (legacy_cache_file, FileTest.EXISTS)) {
                Utils.Filesystem.delete_file (legacy_cache_file);
            }

            return new ReleaseCatalogSnapshot (
                releases,
                (int) root_obj.get_int_member_with_default ("page", 1),
                root_obj.get_boolean_member_with_default ("has_more", false),
                root_obj.get_string_member_with_default ("last_updated", "")
            );
        }

        private string get_cache_file () {
            return Path.build_filename (Globals.CACHE_PATH, tool_id.replace ("/", "_") + ".json");
        }

        private string get_legacy_cache_file () {
            var safe_title = tool_title.replace (":", "_").replace ("/", "_").replace (".", "_").replace (" ", "_");
            return Path.build_filename (Globals.CACHE_PATH, safe_title + ".json");
        }

        // A corrupt cache is expected to be recoverable.  Keep its parse
        // failure local rather than turning a routine refresh into a warning.
        private Json.Node? parse_cache_json (string json) {
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (json, -1);
                return parser.get_root ();
            } catch (Error e) {
                return null;
            }
        }
    }
}
