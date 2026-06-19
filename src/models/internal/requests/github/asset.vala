namespace ProtonPlus.Models.Internal.Requests.Github {
    using ProtonPlus.Models.Internal.Request;
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
            var asset = new Asset ();

            asset.id = obj.get_int_member ("id");
            asset.name = obj.has_member ("name") ? obj.get_string_member ("name") : "";
            asset.content_type = obj.get_string_member ("content_type");
            asset.size = obj.get_int_member ("size");
            asset.digest = obj.get_string_member ("digest");
            asset.download_url = obj.has_member ("browser_download_url") ? obj.get_string_member ("browser_download_url") : "";
            return asset;
        }
    }
}
