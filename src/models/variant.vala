namespace ProtonPlus.Models {
    public class Variant : Object {
        public string id { get; private set; }
        public string name { get; set; }
        public string format { get; set; }
        public bool is_default { get; set; default = false; }
        public string? download_url { get; set; }
        public Tools.Basic runner { get; set; }

        public Variant (
            string name,
            string format,
            bool is_default,
            Tools.Basic runner,
            string? download_url = null,
            string id = ""
        ) {
            this.id = id;
            this.name = name;
            this.format = format;
            this.is_default = is_default;
            this.download_url = download_url;
            this.runner = runner;
        }
    }
}
