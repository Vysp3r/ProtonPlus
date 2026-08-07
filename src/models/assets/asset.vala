namespace ProtonPlus.Models.Assets {
    // Provider responses are normalized to this immutable catalog value.
    public class Asset : Object {
        public string name { get; construct; }
        public string download_url { get; construct; }
        public int64 download_size { get; construct; }

        public Asset (string name, string download_url, int64 download_size = 0) {
            Object (
                name: name,
                download_url: download_url,
                download_size: download_size
            );
        }

        public static Asset from_download_url (string download_url, int64 download_size = 0) {
            var path = download_url.split ("?")[0];
            return new Asset (Path.get_basename (path), download_url, download_size);
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

            if (name == "" || download_url == "")
                return null;

            return new Asset (name, download_url);
        }

        public static bool is_archive_name (string name) {
            return Utils.ArchiveHelper.is_archive_name (name);
        }

        public bool is_archive () {
            return is_archive_name (this.name);
        }
    }
}
