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
    }
}
