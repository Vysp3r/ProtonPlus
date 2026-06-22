namespace ProtonPlus.Models.Internal.Requests {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public abstract class BaseReleases : Object, IReleases {
        public LinkedList<IRelease> list { get; set; default = new LinkedList<IRelease> (); }
        public IRelease? latest { get; set; default = null; }

        public int size {
            get {
                return this.list.size;
            }
        }

        protected BaseReleases (LinkedList<IRelease>? list = null) {
            if (list != null) {
                this.list = list;
            }
        }

        protected BaseReleases.from_json (Json.Array root_array) {
            append_from_json (root_array);
        }

        public IRelease? get_latest () {
            if (this.latest != null) {
                return this.latest;
            }

            if (this.list.size == 0) {
                return null;
            }

            IRelease latest_release = this.list.get (0);
            this.latest = latest_release;
            return latest_release;
        }

        public abstract void append_from_json (Json.Array root_array);

        public void merge (IReleases releases) {
            foreach (IRelease release in releases.list) {
                this.list.add (release);
            }
            this.latest = null;
        }

        public void add (IRelease release) {
            this.list.add (release);
            this.latest = null;
        }

        public void remove (IRelease release) {
            this.list.remove (release);
            this.latest = null;
        }
    }
}
