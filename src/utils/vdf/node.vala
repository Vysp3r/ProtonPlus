namespace ProtonPlus.Utils.VDF {
    public class Node : Gee.TreeMap<string, GLib.Variant> {
        public string node_name;

        public Node (string name) {
            node_name = name;
        }
    }
}