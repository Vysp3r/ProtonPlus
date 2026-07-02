namespace ProtonPlus.Models.Internal.Requests.Gitlab {
    using ProtonPlus.Models.Internal.Requests;
    public class Asset : Object, IAsset {
        public int64 id { get; set; }
        public string name { get; set; }
        public string content_type { get; set; }
        public int64 size { get; set; }
        public string digest { get; set; }
        public string download_url { get; set; }
        public Asset () {

        }

        public IAsset from_json (Json.Object obj) {
            this.id = obj.has_member ("id") ? obj.get_int_member ("id") : 0;
            this.name = obj.has_member ("name") ? obj.get_string_member ("name") : "";
            this.content_type = obj.has_member ("content_type") ? obj.get_string_member ("content_type") : "";
            this.size = obj.has_member ("size") ? obj.get_int_member ("size") : 0;
            this.digest = obj.has_member ("digest") ? obj.get_string_member ("digest") : "";
            this.download_url = obj.has_member ("direct_asset_url") ? obj.get_string_member ("direct_asset_url").replace ("?ref_type=heads", "") : "";
            return this;
        }
    }
}
