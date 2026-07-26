namespace ProtonPlus.Models.Releases {
    public class GitHubAction : Release {
        public string artifacts_url { get; set; }

        public GitHubAction (
            Tools.Basic runner,
            string title,
            string release_date,
            ProtonPlus.Models.Assets.Asset asset,
            string page_url,
            string artifacts_url,
            string upstream_release_id = "",
            string source_tag = ""
        ) {
            this.artifacts_url = artifacts_url;
            this.upstream_release_id = upstream_release_id;
            this.source_tag = source_tag;

            shared (runner, title, release_date, asset, page_url);
        }

        public override Json.Object to_json () {
            var obj = base.to_json ();
            obj.set_string_member ("kind", "github-action");
            obj.set_string_member ("artifacts_url", artifacts_url);
            return obj;
        }

        protected override async string? _after_extraction (string source_path, string extract_path) {
            return yield extract_nested_archive (source_path, extract_path);
        }
    }
}
