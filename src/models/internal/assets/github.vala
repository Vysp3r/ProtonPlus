namespace ProtonPlus.Models.Internal.Assets {
    public class Github : Asset {
        public string description { get; set; }
        public string page_url { get; set; }
        public string release_date { get; set; }
        public int download_size { get; set; }

        public Github (string name,
            string download_url,
            int download_size,
            string description,
            string page_url,
            string release_date) {
            base (name, download_url);
            this.description = description;
            this.page_url = page_url;
            this.release_date = release_date;
            this.download_size = download_size;
        }

        public new Json.Object to_json () {
            var obj = base.to_json ();
            obj.set_string_member ("description", this.description);
            obj.set_string_member ("page_url", this.page_url);
            obj.set_string_member ("release_date", this.release_date);
            obj.set_int_member ("size", this.download_size);

            return obj;
        }

        public new static Github ? from_json (Json.Object obj) {
            if (obj == null) {
                return null;
            }

            string download_url = obj.has_member ("browser_download_url") ? obj.get_string_member ("browser_download_url") : "";
            string name = obj.has_member ("name") ? obj.get_string_member ("name") : "";
            string description = obj.get_string_member ("body").strip ();
            string page_url = obj.get_string_member ("html_url");
            string release_date = obj.get_string_member ("created_at");
            int download_size = (int) obj.get_int_member ("size");

            return new Github (name, download_url, download_size, description, page_url, release_date);
        }
    }
}
