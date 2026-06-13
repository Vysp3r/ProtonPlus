namespace ProtonPlus.Models.Internal.Assets {
    public interface IAsset : Object {
        public abstract string name { get; set; }
        public abstract string download_url { get; set; }

        public abstract Json.Object to_json ();
        public abstract bool is_archive ();
    }
}
