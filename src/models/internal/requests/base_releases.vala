namespace ProtonPlus.Models.Internal.Requests {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public abstract class BaseReleases : Object, IReleases {
        public LinkedList<IRelease> list { get; set; }
        private IRelease? cached_latest = null;

        public int size {
            get {
                return this.list.size;
            }
        }

        protected BaseReleases (LinkedList<IRelease>? list = null) {
            if (list != null) {
                this.list = list;
            } else {
                this.list = new LinkedList<IRelease> ();
            }
        }

        protected BaseReleases.from_json (Json.Array root_array) {
            this.list = new LinkedList<IRelease> ();
            this.cached_latest = null;
            append_from_json (root_array);
        }

        public IRelease? get_latest () {
            if (this.cached_latest != null) {
                return this.cached_latest;
            }

            if (this.list.size == 0) {
                return null;
            }

            IRelease latest_release = this.list.get (0);
            this.cached_latest = latest_release;
            return latest_release;
        }

        public abstract void append_from_json (Json.Array root_array);

        public void merge (IReleases releases) {
            foreach (IRelease release in releases.list) {
                this.list.add (release);
            }
            this.cached_latest = null;
        }

        public void add (IRelease release) {
            this.list.add (release);
            this.cached_latest = null;
        }

        public void remove (IRelease release) {
            this.list.remove (release);
            this.cached_latest = null;
        }
    }
}
