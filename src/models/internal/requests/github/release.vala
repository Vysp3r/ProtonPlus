namespace ProtonPlus.Models.Internal.Requests.Github {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

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
            this.id = obj.has_member ("id") ? obj.get_int_member ("id") : 0;
            this.name = obj.get_string_member_with_default ("name", "");
            this.tag_name = obj.get_string_member_with_default ("tag_name", "");
            this.description = obj.get_string_member_with_default ("body", "").strip ();
            this.page_url = obj.get_string_member_with_default ("html_url", "");
            this.draft = obj.get_boolean_member_with_default ("draft", false);
            this.prereleas = obj.get_boolean_member_with_default ("prerelease", false);

            var created_at_raw = obj.get_string_member_with_default ("created_at", "");
            var parsed_created_at = new DateTime.from_iso8601 (created_at_raw, null);
            this.created_at = parsed_created_at ?? new DateTime.now_utc ();

            if (this.assets == null)
                this.assets = new Gee.LinkedList<Asset> ();
            else
                this.assets.clear ();

            Json.Array? assets_array = obj.get_array_member ("assets");
            if (assets_array != null) {
                for (int i = 0; i < assets_array.get_length (); i++) {
                    Json.Object asset_obj = assets_array.get_object_element (i);
                    Asset asset = new Asset ();
                    asset.from_json (asset_obj);
                    this.assets.add (asset);
                }
            }

            return this;
        }
    }
}
