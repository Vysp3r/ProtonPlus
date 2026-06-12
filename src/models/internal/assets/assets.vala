namespace ProtonPlus.Models.Internal.Assets {
    public class Assets : Object {
        public Gee.LinkedList<Asset> list { get; set; default = new Gee.LinkedList<Asset> (); }

        public Assets () {
        }

        public Json.Object to_json () {
            var obj = new Json.Object ();

            var l = new Json.Array ();

            foreach (var item in this.list) {
                l.add_object_element (item.to_json ());
            }

            obj.set_array_member ("assets", l);

            return obj;
        }

        public static Assets ? from_json (Json.Array? list_array) {
            Assets res = new Assets ();
            if (list_array == null) {
                return res;
            }

            for (int i = 0; i < list_array.get_length (); i++) {
                var asset = list_array.get_object_element (i);
                res.list.add (Asset.from_json (asset));
            }

            return res;
        }
    }
}