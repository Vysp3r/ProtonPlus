using Gee;

namespace ProtonPlus.Models.Steam {

    public class LibraryFolder : GLib.Object {
        public int id { get; set; }
        public string path { get; set; }
        public string label { get; set; }
        public int64 totalsize { get; set; }

        public HashMap<string, string> apps { get; set; }

        public LibraryFolder () {
            this.apps = new HashMap<string, string> ();
        }
    }
}
