namespace ProtonPlus.Models.VDF {
    public class Node : Gee.TreeMap<string, GLib.Variant> {
        public string node_name;

        static int case_insensitive_compare (string str1, string str2) {
            return str1.casefold().collate(str2.casefold());
        }

        public Node (string name) {
            base((CompareDataFunc<string>) case_insensitive_compare);
            node_name = name;
        }
    }
}