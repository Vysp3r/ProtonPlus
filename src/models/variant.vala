namespace ProtonPlus.Models {
    /// A provider-normalized release variant.  Tool configuration keeps its
    /// own runner-definition variant type, while this type is pure metadata.
    public class Variant : Object {
        public string id { get; private set; }
        public string name { get; private set; }
        public string format { get; private set; }
        public bool is_default { get; private set; default = false; }
        public string? download_url { get; set; }

        public Variant (
            string id,
            string name,
            string format,
            bool is_default,
            string? download_url = null
        ) {
            this.id = id;
            this.name = name;
            this.format = format;
            this.is_default = is_default;
            this.download_url = download_url;
        }
    }
}
