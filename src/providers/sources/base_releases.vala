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
            this.sort ();
        }

        public IRelease? get_latest () {
            this.sort ();
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
            this.sort ();
        }

        public void add (IRelease release) {
            this.list.add (release);
            this.cached_latest = null;
            this.sort ();
        }

        public void remove (IRelease release) {
            this.list.remove (release);
            this.cached_latest = null;
            this.sort ();
        }

        public void sort () {
            this.list.sort ((a, b) => {
                int a_major, a_minor;
                int b_major, b_minor;

                bool has_a = extract_version (a.name, out a_major, out a_minor);
                bool has_b = extract_version (b.name, out b_major, out b_minor);

                if (has_a && has_b) {
                    if (a_major != b_major)
                        return b_major - a_major;

                    if (a_minor != b_minor)
                        return b_minor - a_minor;
                } else if (has_a) {
                    return -1;
                } else if (has_b) {
                    return 1;
                }

                return strcmp (
                    b.name.collate_key_for_filename (),
                    a.name.collate_key_for_filename ()
                );
            });

            this.cached_latest = null;
        }

        private static bool extract_version (string name, out int major, out int minor) {
            major = 0;
            minor = 0;

            try {
                var regex = new Regex ("""(\d+)\.(\d+)""");
                MatchInfo match;

                if (regex.match (name, 0, out match)) {
                    major = int.parse (match.fetch (1));
                    minor = int.parse (match.fetch (2));
                    return true;
                }
            } catch (RegexError e) {
            }

            return false;
        }
    }
}
