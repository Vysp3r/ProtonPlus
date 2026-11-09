namespace ProtonPlus.Providers.Sources {
    // TinkerGame uses source archives and includes alpha releases. Ordinary
    // GitHub providers require uploaded assets and exclude prereleases.
    public class TinkerGameReleaseSource : Object, ReleaseSource {
        public async Models.Tools.ReleasePageResult fetch_page (
            Models.Providers.ProviderDefinition definition, int requested_page, int limit
        ) {
            var response = yield Utils.Web.get_request (
                "%s?per_page=%i&page=%i".printf (definition.endpoint, limit, requested_page),
                Utils.Web.GetRequestType.GITHUB);
            if (response.code != ReturnCode.VALID_REQUEST)
                return Models.Tools.ReleasePageResult.failure (response.code);
            return parse_response (response.body, requested_page, limit);
        }

        public Models.Tools.ReleasePageResult parse_response (string body, int page, int limit) {
            var array = ReleaseSourceSupport.parse_array (body);
            if (array == null)
                return Models.Tools.ReleasePageResult.failure (ReturnCode.INVALID_DATA);
            var releases = new Gee.LinkedList<Models.Release> ();
            for (var index = 0; index < array.get_length (); index++) {
                var node = array.get_element (index);
                if (node.get_node_type () != Json.NodeType.OBJECT)
                    continue;
                var entry = node.get_object ();
                if (entry.get_boolean_member_with_default ("draft", false))
                    continue;
                var tag = entry.get_string_member_with_default ("tag_name", "");
                var url = entry.get_string_member_with_default ("zipball_url", "");
                if (tag == "" || url == "")
                    continue;
                releases.add (new Models.Release (
                    "TinkerGame " + (tag.has_prefix ("v") ? tag.substring (1) : tag),
                    entry.get_string_member_with_default ("body", ""),
                    ReleaseSourceSupport.get_iso8601_date (entry, "published_at"),
                    new Models.Assets.Asset ("tinkergame.zip", url),
                    entry.get_string_member_with_default ("html_url", ""),
                    0, tag, tag, Models.Release.Kind.TINKER_GAME));
                // One managed slot: only offer the newest published release.
                break;
            }
            return Models.Tools.ReleasePageResult.success (new Models.Tools.ReleasePage (
                releases, page + 1, releases.size == 0 && array.get_length () == limit));
        }
    }
}
