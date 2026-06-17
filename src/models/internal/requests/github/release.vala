namespace ProtonPlus.Models.Internal.Requests.Github {
    using Gee;

    public class Release : Object {
        public int64 id { get; set; }
        public string name { get; set; }
        public string tag_name { get; set; }
        public string description { get; set; }
        public string page_url { get; set; }
        public bool draft { get; set; }
        public bool prereleas { get; set; }
        public DateTime created_at { get; set; }
        public Gee.LinkedList<Requests.Github.Asset> assets { get; set; default = new Gee.LinkedList<Requests.Github.Asset> (); }

        public Release () {
        }

        public Release.from_json (Json.Object object) {
            this.id = object.get_int_member ("id");
            this.name = object.get_string_member ("name");
            this.tag_name = object.get_string_member ("tag_name");
            this.description = object.get_string_member ("body").strip ();
            this.page_url = object.get_string_member ("html_url");
            this.draft = object.get_boolean_member_with_default ("draft", false);
            this.prereleas = object.get_boolean_member_with_default ("prerelease", false);
            this.created_at = new DateTime.from_iso8601 (object.get_string_member ("created_at"), null);

            Json.Array? assets_array = object.get_array_member ("assets");
            if (assets_array != null) {
                for (int i = 0; i < assets_array.get_length (); i++) {
                    Json.Object asset_obj = assets_array.get_object_element (i);
                    Asset asset = new Asset.from_json (asset_obj);
                    this.assets.add (asset);
                }
            }
        }
    }
}
