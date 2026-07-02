namespace ProtonPlus.Models.Internal.Assets {
    using Gee;

    public class Collection : Object {
        public Gee.LinkedList<IAsset> list { get; set; default = new Gee.LinkedList<IAsset> (); }
        public Gee.LinkedList<IAsset> archives { get; set; default = new Gee.LinkedList<IAsset> (); }

        public Json.Object to_json () {
            var obj = new Json.Object ();
            var l = new Json.Array ();

            foreach (var asset in this.list) {
                l.add_object_element (asset.to_json ());
            }

            obj.set_array_member ("assets", l);
            return obj;
        }

        /*public static Collection<T> ? from_json (Json.Array? list_array) {
            Collection res = new Collection<T> ();
            if (list_array == null) {
                return res;
            }

            for (int i = 0; i < list_array.get_length (); i++) {
                var asset = list_array.get_object_element (i);
                res.list.add (Asset.from_json (asset));
            }

            res.archives = res.get_archives ();

            return res;
        }*/

        public int get_length () {
            return this.list.size;
        }

        public IAsset? first () {
            return this.archives.first ();
        }

        public IAsset? get_by_position (int position) {
            if (position < 0 || this.list.is_empty || position >= this.list.size)return null;

            var res = this.list.get (position);
            return res;
        }

        public Gee.LinkedList<IAsset> filter_archives () {
            var filtered = new Gee.LinkedList<IAsset> ();

            foreach (var item in this.list) {
                var asset = item as IAsset;
                if (asset != null && asset.is_archive ()) {
                    filtered.add (asset);
                }
            }

            return filtered;
        }
    }
}
