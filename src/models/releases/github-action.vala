namespace ProtonPlus.Models.Releases {
    public class GitHubAction : Release {
        public string artifacts_url { get; set; }

        public GitHubAction (Tools.Basic runner, string title, string release_date, string download_url, string page_url, string artifacts_url) {
            this.artifacts_url = artifacts_url;

            shared (runner, title, release_date, download_url, page_url);
        }

        public override Json.Object to_json () {
            var obj = base.to_json ();
            obj.set_string_member ("kind", "github-action");
            obj.set_string_member ("artifacts_url", artifacts_url);
            return obj;
        }

        protected override async string _after_extraction (string source_path, string extract_path) {
            return yield Utils.Filesystem.extract (extract_path, source_path.substring (0, source_path.length - 4).replace (extract_path, ""), ".tar", () => canceled);
        }
    }
}
