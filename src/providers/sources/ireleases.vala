namespace ProtonPlus.Models.Internal.Requests {

    public interface IReleases : Object {
        public abstract Gee.LinkedList<IRelease> list { get; set; }
        public abstract void append_from_json (Json.Array root_array);

        public abstract void merge (IReleases releases);

        public abstract void add (IRelease release);

        public abstract void remove (IRelease release);

        public abstract IRelease? get_latest ();
    }
}
