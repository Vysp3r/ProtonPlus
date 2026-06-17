namespace ProtonPlus.Models.Internal.Requests.Github {
    public class Asset : Object {
        public int64 id { get; set; }
        public string name { get; set; }
        public string content_type { get; set; }
        public int64 size { get; set; }
        public string digest { get; set; }
        public string download_url { get; set; }
        public Asset () {

        }

        public Asset.from_json (Json.Object obj) {
            this.id = obj.get_int_member ("id");
            this.name = obj.has_member ("name") ? obj.get_string_member ("name") : "";
            this.content_type = obj.get_string_member ("content_type");
            this.size = obj.get_int_member ("size");
            this.digest = obj.get_string_member ("digest");
            this.download_url = obj.has_member ("browser_download_url") ? obj.get_string_member ("browser_download_url") : "";
        }
    }
}
