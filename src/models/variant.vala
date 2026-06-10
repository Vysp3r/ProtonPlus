namespace ProtonPlus.Models {
    public class Variant : Object {
        public string name { get; set; }
        public string format { get; set; }
        public bool? is_default { get; set; }

        public Variant (string name, string format, bool? is_default) {
            this.name = name;
            this.format = format;
            this.is_default = is_default == null ? false : is_default;
        }
    }
}
