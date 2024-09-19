namespace ProtonPlus.Models {
    public abstract class Release : Object {
        public Widgets.ReleaseRow row { get; set; }

        public Runner runner { get; set; }
        public string title { get; set; }
        public string description { get; set; }
        public string release_date { get; set; }
        public string download_url { get; set; }
        public string page_url { get; set; }

        internal bool installed { get; set; }
        internal bool canceled { get; set; }

        internal abstract void refresh_interface_state(bool can_reset_processing = false);
    }
}