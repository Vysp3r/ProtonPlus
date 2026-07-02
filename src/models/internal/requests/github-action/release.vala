namespace ProtonPlus.Models.Internal.Requests.GithubAction {
    using ProtonPlus.Models.Internal.Requests;

    public class Release : Object, IRelease {
        public int64 id { get; set; }
        public string title { get; set; }
        public string page_url { get; set; }
        public string artifacts_url { get; set; }
        public string status { get; set; }
        public string conclusion { get; set; }
        public DateTime created_at { get; set; }

        public Release () {
        }

        public IRelease from_json (Json.Object obj) {
            this.id = obj.has_member ("id") ? obj.get_int_member ("id") : 0;
            this.title = obj.has_member ("run_number") ? obj.get_int_member ("run_number").to_string () : "";
            this.page_url = obj.get_string_member_with_default ("html_url", "");
            this.artifacts_url = obj.get_string_member_with_default ("artifacts_url", "");
            this.status = obj.get_string_member_with_default ("status", "");
            this.conclusion = obj.get_string_member_with_default ("conclusion", "");

            var created_at_raw = obj.get_string_member_with_default ("created_at", "");
            var parsed_created_at = new DateTime.from_iso8601 (created_at_raw, null);
            this.created_at = parsed_created_at ?? new DateTime.now_utc ();

            return this;
        }
    }
}
