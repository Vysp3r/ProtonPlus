namespace ProtonPlus.Utils {
    public class CacheManager {
        // Install attempts keep both their temporary workspace and their
        // downloaded archives below CACHE_PATH.  Clearing the cache must not
        // remove either while an attempt is still using it.
        private static uint active_cache_operations = 0;
        private static bool clearing_cache = false;

        private static async void wait_for_cache_state_change () {
            Timeout.add (10, () => {
                wait_for_cache_state_change.callback ();
                return Source.REMOVE;
            });
            yield;
        }

        public static async void begin_cache_operation () {
            // A continuation runs on the main context, so incrementing after
            // the wait closes the race with clear_cache().
            while (clearing_cache)
                yield wait_for_cache_state_change ();

            active_cache_operations++;
        }

        public static void end_cache_operation () {
            assert (active_cache_operations > 0);
            active_cache_operations--;
        }

        public static async void save_releases (Models.Tool tool) {
            var cache_file = get_cache_file (tool);
            var root_obj = new Json.Object ();
            root_obj.set_string_member ("last_updated", tool.last_updated);
            root_obj.set_int_member ("page", tool.page);
            root_obj.set_boolean_member ("has_more", tool.has_more);

            var releases_array = new Json.Array ();
            foreach (var release in tool.releases) {
                // Don't cache the "Latest" virtual release.
                if (release is Models.Releases.Latest)
                    continue;

                releases_array.add_object_element (release.to_json ());
            }
            root_obj.set_array_member ("releases", releases_array);

            var generator = new Json.Generator ();
            var root_node = new Json.Node (Json.NodeType.OBJECT);
            root_node.set_object (root_obj);
            generator.set_root (root_node);

            var json = generator.to_data (null);
            Utils.Filesystem.modify_file (cache_file, json);
        }

        public static async void load_releases (Models.Tool tool) {
            var cache_file = get_cache_file (tool);
            if (!FileUtils.test (cache_file, FileTest.EXISTS))
                return;

            if (tool.releases == null)
                tool.releases = new Gee.LinkedList<Models.Release> ();

            var json = Utils.Filesystem.get_file_content (cache_file);
            if (json == "")
                return;

            var root_node = Utils.Parser.get_node_from_json (json);
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT)
                return;

            var root_obj = root_node.get_object ();
            if (root_obj.has_member ("last_updated"))
                tool.last_updated = root_obj.get_string_member_with_default ("last_updated", "");
            if (root_obj.has_member ("page"))
                tool.page = (int) root_obj.get_int_member ("page");
            if (root_obj.has_member ("has_more"))
                tool.has_more = root_obj.get_boolean_member ("has_more");

            if (!root_obj.has_member ("releases"))
                return;

            var releases_node = root_obj.get_member ("releases");
            if (releases_node == null || releases_node.get_node_type () != Json.NodeType.ARRAY)
                return;

            var releases_array = releases_node.get_array ();

            tool.releases.clear ();
            for (var i = 0; i < releases_array.get_length (); i++) {
                var release_obj = releases_array.get_object_element (i);
                if (release_obj == null) {
                    continue;
                }
                var release = Models.Release.from_json (tool, release_obj);
                if (release != null)
                    tool.releases.add (release);
            }

            if (tool is Models.Tools.Basic && tool.releases.size > 0) {
                var latest_release = new Models.Releases.Latest (
                    tool as Models.Tools.Basic,
                    "%s Latest".printf (tool.title),
                    tool.releases[0].description,
                    tool.releases[0].release_date,
                    tool.releases[0].download_url,
                    tool.releases[0].page_url,
                    tool.releases[0].title
                );

                foreach (var variant in tool.releases[0].variants) {
                    latest_release.variants.add (new Models.Variant (
                        variant.name,
                        variant.format,
                        variant.is_default,
                        tool as Models.Tools.Basic,
                        variant.download_url
                    ));
                }

                tool.releases.insert (0, latest_release);
            }
        }

        private static string get_cache_file (Models.Tool tool) {
            string id = tool.title;
            // Simple hash or just replace special chars
            var safe_id = id.replace (":", "_").replace ("/", "_").replace (".", "_").replace (" ", "_");
            return Path.build_filename (Globals.CACHE_PATH, safe_id + ".json");
        }

        public static async bool clear_cache () {
            // Serialize clear requests as well as install attempts.  Existing
            // operations are allowed to finish (or be cancelled) so their
            // cleanup never races deletion of CACHE_PATH.
            while (clearing_cache)
                yield wait_for_cache_state_change ();

            clearing_cache = true;
            while (active_cache_operations > 0)
                yield wait_for_cache_state_change ();

            bool success = true;
            if (FileUtils.test (Globals.CACHE_PATH, FileTest.IS_DIR)) {
                if (!yield Utils.Filesystem.delete_directory (Globals.CACHE_PATH))
                    success = false;
            }

            if (success)
                success = Utils.Filesystem.create_directory (Globals.CACHE_PATH);

            clearing_cache = false;
            return success;
        }
    }
}
