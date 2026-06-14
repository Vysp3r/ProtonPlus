namespace ProtonPlus.Models.Internal.Assets {
    public class Github : Asset {
        public int download_size { get; set; }

        public Github (string name, string download_url, int download_size) {
            base (name, download_url);
            this.download_size = download_size;
        }

        public new Json.Object to_json () {
            var obj = base.to_json ();
            obj.set_int_member ("size", this.download_size);

            return obj;
        }

        public new static Github ? from_json (Json.Object? obj) {
            if (obj == null) {
                return null;
            }

            var generator = new Json.Generator ();
            generator.set_root (new Json.Node.alloc ().init_object (obj));

            string download_url = obj.has_member ("browser_download_url") ? obj.get_string_member ("browser_download_url") : "";
            string name = obj.has_member ("name") ? obj.get_string_member ("name") : "";
            int download_size = (int) obj.get_int_member ("size");

            return new Github (name, download_url, download_size);
        }
    }
}
