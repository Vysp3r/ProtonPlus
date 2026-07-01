namespace ProtonPlus.Models.Tools {
    public class GitHubAction : Basic {
        internal string url_template { get; set; }

        public GitHubAction () {
            get_request_type = Utils.Web.GetRequestType.GITHUB;
        }

        public override async Gee.LinkedList<Release> load_more (out ReturnCode code) {
            var _releases = new Gee.LinkedList<Release> ();

            if (source_runner == null) {
                code = ReturnCode.UNKNOWN_ERROR;
                return _releases;
            }

            var current_page = page;
            var reached_end = false;
            const int PAGE_SIZE = 25;

            while (_releases.size == 0 && !reached_end) {
                var source_releases = yield source_runner.request_releases (current_page, PAGE_SIZE, out code);

                if (code != ReturnCode.RELEASES_LOADED || source_releases == null)
                    return _releases;

                foreach (var source_release_item in source_releases.list) {
                    var source_release = source_release_item as Internal.Requests.GithubAction.Release;
                    if (source_release == null)
                        continue;

                    if (source_release.status == "completed" && source_release.conclusion == "success") {
                        string download_url = url_template.replace ("{id}", source_release.id.to_string ());
                        var release = new Releases.GitHubAction (
                            this,
                            source_release.title,
                            source_release.created_at.format_iso8601 (),
                            download_url,
                            source_release.page_url,
                            source_release.artifacts_url
                        );

                        _releases.add (release);
                    }
                }

                reached_end = source_releases.list.size < PAGE_SIZE;
                current_page++;
            }

            page = current_page;
            has_more = !reached_end;
            code = ReturnCode.RELEASES_LOADED;

            return _releases;
        }
    }
}
