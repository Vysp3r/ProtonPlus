namespace ProtonPlus.Models.Internal.Requests {
    using Gee;

    public interface IAsset: Object {
        public abstract IAsset from_json (Json.Object obj);
    }
}
