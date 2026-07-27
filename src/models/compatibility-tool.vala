namespace ProtonPlus.Models {
    // A launcher-selectable compatibility entry discovered locally or created
    // synthetically for Steam's Default and Native choices.  It deliberately
    // has no provider, catalog, inventory, or installation state.
    public class CompatibilityTool : Object {
        public string display_title { get; set; default = ""; }
        public string internal_title { get; set; default = ""; }
        public string path { get; set; default = ""; }
        public int sort_priority { get; set; default = 1000; }

        public CompatibilityTool (
            string display_title,
            string internal_title = "",
            string path = ""
        ) {
            this.display_title = display_title;
            this.internal_title = internal_title != "" ? internal_title : display_title;
            this.path = path;
        }
    }
}
