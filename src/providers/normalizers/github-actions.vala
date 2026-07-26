namespace ProtonPlus.Providers.Normalizers {
    using ProtonPlus.Models;
    using ProtonPlus.Models.Tools;
    public class GitHubAction : Basic {
        internal string url_template { get; set; }

        public GitHubAction () {
            get_request_type = Utils.Web.GetRequestType.GITHUB;
        }

        public override async ReleasePage? fetch_release_page (int requested_page, out ReturnCode code) {
            var _releases = new Gee.LinkedList<Release> ();

            if (source_runner == null) {
                code = ReturnCode.INVALID_CONFIGURATION;
                return null;
            }

            var current_page = requested_page;
            var reached_end = false;

            while (_releases.size == 0 && !reached_end) {
                var source_releases = yield source_runner.request_releases (current_page, RELEASE_PAGE_SIZE, out code);

                if (code != ReturnCode.RELEASES_LOADED || source_releases == null)
                    return null;

                foreach (var source_release_item in source_releases.list) {
                    var source_release = source_release_item as ProtonPlus.Providers.Sources.GitHubActions.Release;
                    if (source_release == null)
                        continue;

                    if (source_release.status == "completed" && source_release.conclusion == "success") {
                        string download_url = url_template.replace ("{id}", source_release.id.to_string ());
                        var asset = ProtonPlus.Models.Assets.Asset.from_download_url (download_url);
                        var release = new Release (
                            source_release.title,
                            "",
                            source_release.created_at.format_iso8601 (),
                            asset,
                            source_release.page_url,
                            0,
                            source_release.id > 0 ? source_release.id.to_string () : "",
                            "",
                            Release.Kind.GITHUB_ACTION,
                            source_release.artifacts_url
                        );

                        _releases.add (release);
                    }
                }

                reached_end = source_releases.list.size < RELEASE_PAGE_SIZE;
                current_page++;
            }

            code = ReturnCode.RELEASES_LOADED;
            return new ReleasePage (_releases, current_page, !reached_end);
        }
    }
}
