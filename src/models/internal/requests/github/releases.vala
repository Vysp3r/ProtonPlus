namespace ProtonPlus.Models.Internal.Requests.Github {
    using Gee;
    using ProtonPlus.Models.Internal.Request;

    public class Releases : Object, IReleases {
        public LinkedList<IRelease> list { get; set; default = new LinkedList<IRelease> (); }

        public int size {
            get {
                return this.list.size;
            }
        }

        public Releases (LinkedList<IRelease>? list = null) {
            if (list != null) {
                this.list = list;
            }
        }

        public Releases.from_json (Json.Array root_array) {
            append_from_json (root_array);
        }

        public void append_from_json (Json.Array root_array) {
            for (int i = 0; i < root_array.get_length (); i++) {
                Json.Object object = root_array.get_object_element (i);
                IRelease release = new Release ();
                release.from_json (object);
                this.list.add (release);
            }
        }

        public void merge (IReleases releases) {
            foreach (IRelease release in releases.list) {
                this.list.add (release);
            }
        }

        public void add (IRelease release) {
            this.list.add (release);
        }

        public void remove (IRelease release) {
            this.list.remove (release);
        }
    }
}
