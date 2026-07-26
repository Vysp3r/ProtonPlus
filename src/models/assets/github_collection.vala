namespace ProtonPlus.Models.Assets {
    public class GitHubCollection : Collection {
        public static new GitHubCollection ? from_json (Json.Array? list_array) {

            var res = new GitHubCollection ();
            if (list_array == null) {
                return res;
            }

            for (int i = 0; i < list_array.get_length (); i++) {
                var asset_obj = list_array.get_object_element (i);
                var parsed = GitHub.from_json (asset_obj);
                if (parsed != null) {
                    res.list.add (parsed);
                }
            }

            res.archives = res.filter_archives ();
            return res;
        }
    }
}
