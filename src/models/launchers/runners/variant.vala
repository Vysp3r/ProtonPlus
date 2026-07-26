namespace ProtonPlus.Models.Launchers.Runners {
    public class Variant : Object {
        public string id { get; private set; }
        public string name { get; set; }
        public string format { get; set; }
        public bool is_default { get; set; default = false; }

        public Variant (string id, string name, string format, bool is_default) {
            this.id = id;
            this.name = name;
            this.format = format;
            this.is_default = is_default;
        }
    }
}
