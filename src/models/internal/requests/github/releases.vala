namespace ProtonPlus.Models.Internal.Requests.Github {
    using Gee;

    public class Releases : Object {
        public Gee.LinkedList<Requests.Github.Release> list { get; set; default = new Gee.LinkedList<Requests.Github.Release> (); }

        public int size {
            get {
                return this.list.size;
            }
        }

        public Releases (Gee.LinkedList<Requests.Github.Release>? list = null) {
            if (list != null) {
                this.list = list;
            }
        }

        public Releases.from_json (Json.Array root_array) {
            for (int i = 0; i < root_array.get_length (); i++) {
                Json.Object object = root_array.get_object_element (i);
                Release release = new Release.from_json (object);
                this.list.add (release);
            }
        }

        public void add (Release release) {
            this.list.add (release);
        }

        public void remove (Release release) {
            this.list.remove (release);
        }
    }
}
