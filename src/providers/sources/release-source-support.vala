namespace ProtonPlus.Providers.Sources {
    internal class ReleaseSourceSupport : Object {
        public static Json.Array? parse_array (string response_body) {
            Json.Node? root_node;
            try {
                root_node = Json.from_string (response_body);
            } catch (Error e) {
                return null;
            }
            if (root_node == null || root_node.get_node_type () != Json.NodeType.ARRAY)
                return null;

            return root_node.get_array ();
        }

        public static string get_iso8601_date (Json.Object object, string member) {
            var raw = object.get_string_member_with_default (member, "");
            var parsed = new DateTime.from_iso8601 (raw, null);
            return (parsed ?? new DateTime.now_utc ()).format_iso8601 ();
        }

        public static void add_variants (Models.Release release, Gee.Iterable<Models.Variant> variants) {
            foreach (var variant in variants)
                release.variants.add (variant);
        }
    }
}
