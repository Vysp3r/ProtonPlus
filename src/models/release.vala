namespace ProtonPlus.Models {
    public abstract class Release : Object {
        public Runner runner { get; set; }
        public string title { get; set; }
        public string displayed_title { get; set; }
        public string description { get; set; }
        public string release_date { get; set; }
        public string download_url { get; set; }
        public string page_url { get; set; }
        public bool canceled { get; set; }
        public string progress { get; set; }
        public signal void send_message (string message);
    }
}