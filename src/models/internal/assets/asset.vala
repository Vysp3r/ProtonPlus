namespace ProtonPlus.Models.Internal.Assets {
    public class Asset : Object, IAsset {
        public string name { get; set; }
        public string download_url { get; set; }

        public Asset (string name, string download_url) {
            this.name = name;
            this.download_url = download_url;
        }

        public Json.Object to_json () {
            var obj = new Json.Object ();
            obj.set_string_member ("name", this.name);
            obj.set_string_member ("download_url", this.download_url);

            return obj;
        }

        public static Asset ? from_json (Json.Object obj) {
            if (obj == null) {
                return null;
            }

            string download_url = obj.has_member ("download_url") ? obj.get_string_member ("download_url") : "";
            string name = obj.has_member ("name") ? obj.get_string_member ("name") : "";

            return new Asset (name, download_url);
        }

        public bool is_archive () {
            try {
                var regex = new Regex ("\\.(zip|tar\\.gz|tgz|tar\\.xz|tar\\.bz2|tbz2|7z|rar)$", RegexCompileFlags.CASELESS);
                return regex.match (this.name);
            } catch (RegexError e) {
                warning ("Error while regex matching: %s", e.message);
                return false;
            }
        }
    }
}