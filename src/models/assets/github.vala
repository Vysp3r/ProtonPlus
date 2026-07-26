namespace ProtonPlus.Models.Assets {
    public class GitHub : Asset {
        public int download_size { get; set; }

        public GitHub (string name, string download_url, int download_size) {
            base (name, download_url);
            this.download_size = download_size;
        }

        public new Json.Object to_json () {
            var obj = base.to_json ();
            obj.set_int_member ("size", this.download_size);

            return obj;
        }

        public new static GitHub ? from_json (Json.Object? obj) {
            if (obj == null) {
                return null;
            }

            string download_url = obj.has_member ("browser_download_url") ? obj.get_string_member ("browser_download_url") : "";
            string name = obj.has_member ("name") ? obj.get_string_member ("name") : "";
            int download_size = (int) obj.get_int_member ("size");

            return new GitHub (name, download_url, download_size);
        }
    }
}
