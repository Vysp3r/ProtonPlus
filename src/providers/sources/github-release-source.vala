namespace ProtonPlus.Providers.Sources {
    public class GitHubReleaseSource : Object, ReleaseSource {
        public async Models.Tools.ReleasePageResult fetch_page (
            Models.Providers.ProviderDefinition definition,
            int requested_page,
            int limit
        ) {
            var response = yield Utils.Web.get_request (
                "%s?per_page=%i&page=%i".printf (definition.endpoint, limit, requested_page),
                Utils.Web.GetRequestType.GITHUB
            );
            if (response.code != ReturnCode.VALID_REQUEST)
                return Models.Tools.ReleasePageResult.failure (response.code);

            return parse_response (definition, response.body, requested_page, limit);
        }

        public Models.Tools.ReleasePageResult parse_response (
            Models.Providers.ProviderDefinition definition,
            string response_body,
            int requested_page,
            int limit
        ) {
            return GitHubCompatibleReleaseParser.parse (
                definition,
                response_body,
                requested_page,
                limit
            );
        }

        internal async Models.ReleaseLookupResult fetch_tag (Models.Providers.ProviderDefinition definition, string tag,
            Cancellable cancellable) {
            var response = yield Utils.Web.get_request (
                "%s/tags/%s".printf (definition.endpoint, Uri.escape_string (tag, null, false)),
                Utils.Web.GetRequestType.GITHUB, cancellable
            );
            if (response.status_code == 404)
                return Models.ReleaseLookupResult.empty ();
            if (response.code != ReturnCode.VALID_REQUEST)
                return Models.ReleaseLookupResult.failure (response.code);

            return parse_tag (definition, tag, response.body ?? "");
        }

        public static Models.ReleaseLookupResult parse_tag (Models.Providers.ProviderDefinition definition, string tag,
            string body) {
            var parser = new Json.Parser ();
            try {
                parser.load_from_data (body);
            } catch (Error error) {
                return Models.ReleaseLookupResult.failure (ReturnCode.INVALID_DATA);
            }
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT)
                return Models.ReleaseLookupResult.failure (ReturnCode.INVALID_DATA);
            var object = root.get_object ();
            var release = object.get_string_member_with_default ("tag_name", "") == tag
                ? GitHubCompatibleReleaseParser.parse_release (definition, object, true) : null;
            return release == null ? Models.ReleaseLookupResult.empty () : Models.ReleaseLookupResult.found (release);
        }
    }
}
