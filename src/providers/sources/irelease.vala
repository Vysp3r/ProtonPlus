namespace ProtonPlus.Models.Internal.Requests {
    public interface IRelease: Object {
        public abstract string name { get; set; }
        public abstract IRelease from_json (Json.Object obj);
    }
}
