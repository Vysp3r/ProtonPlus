namespace ProtonPlus.Models.Internal.Requests.Github {
    using Gee;
    using ProtonPlus.Models.Internal.Request;

    public class Release : Object, IRelease {
        public int64 id { get; set; }
        public string name { get; set; }
        public string tag_name { get; set; }
        public string description { get; set; }
        public string page_url { get; set; }
        public bool draft { get; set; }
        public bool prereleas { get; set; }
        public DateTime created_at { get; set; }
        public Gee.LinkedList<Asset> assets { get; set; default = new Gee.LinkedList<Asset> (); }

        public Release () {
        }

        public IRelease from_json (Json.Object obj) {
            var release = new Release ();
            release.id = obj.get_int_member ("id");
            release.name = obj.get_string_member ("name");
            release.tag_name = obj.get_string_member ("tag_name");
            release.description = obj.get_string_member ("body").strip ();
            release.page_url = obj.get_string_member ("html_url");
            release.draft = obj.get_boolean_member_with_default ("draft", false);
            release.prereleas = obj.get_boolean_member_with_default ("prerelease", false);
            release.created_at = new DateTime.from_iso8601 (obj.get_string_member ("created_at"), null);

            Json.Array? assets_array = obj.get_array_member ("assets");
            if (assets_array != null) {
                for (int i = 0; i < assets_array.get_length (); i++) {
                    Json.Object asset_obj = assets_array.get_object_element (i);
                    Asset asset = new Asset ();
                    asset.from_json (asset_obj);
                    release.assets.add (asset);
                }
            }
            return release;
        }
    }
}
