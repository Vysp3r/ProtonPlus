namespace ProtonPlus.Models.Internal.Request {

    public interface IReleases {
        public abstract Gee.LinkedList<IRelease> list { get; set; default = new Gee.LinkedList<IRelease> (); }
        public abstract void append_from_json (Json.Array root_array);

        public abstract void merge (IReleases releases);

        public abstract void add (IRelease release);

        public abstract void remove (IRelease release);
    }
}
