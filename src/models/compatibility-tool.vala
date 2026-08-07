namespace ProtonPlus.Models {
    public enum CompatibilityToolRuntimeKind {
        UNKNOWN,
        NATIVE,
        PROTON
    }

    // A launcher-selectable compatibility entry discovered locally or created
    // synthetically for Steam's Default and Native choices.  It deliberately
    // has no provider, catalog, inventory, or installation state.
    public class CompatibilityTool : Object {
        public string display_title { get; set; default = ""; }
        public string internal_title { get; set; default = ""; }
        public string path { get; set; default = ""; }
        public int sort_priority { get; set; default = 1000; }
        /* Providers may set this only when their runtime classification is
         * explicit.  Unknown deliberately does not grant variant capabilities. */
        public CompatibilityToolRuntimeKind runtime_kind { get; set; default = CompatibilityToolRuntimeKind.UNKNOWN; }

        public CompatibilityTool (
            string display_title,
            string internal_title = "",
            string path = "",
            CompatibilityToolRuntimeKind runtime_kind = CompatibilityToolRuntimeKind.UNKNOWN
        ) {
            this.display_title = display_title;
            this.internal_title = internal_title != "" ? internal_title : display_title;
            this.path = path;
            this.runtime_kind = runtime_kind;
        }
    }
}
