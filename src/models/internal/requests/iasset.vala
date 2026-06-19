namespace ProtonPlus.Models.Internal.Request {
    using Gee;

    public interface IAsset: Object {
        public abstract IAsset from_json (Json.Object obj);
    }
}
