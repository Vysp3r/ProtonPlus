namespace ProtonPlus.Models.Internal.Assets {
    public class AssetCollection : Collection {

       public static new AssetCollection? from_json (Json.Array? list_array) {
            var res = new AssetCollection ();
            if (list_array == null) {
                return res;
            }

            for (int i = 0; i < list_array.get_length (); i++) {
                var asset_obj = list_array.get_object_element (i);
                var parsed = Asset.from_json (asset_obj);
                if (parsed != null) {
                    res.list.add (parsed);
                }
            }

            res.archives = res.filter_archives ();
            return res;
        }
    }
}
