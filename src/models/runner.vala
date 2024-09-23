namespace ProtonPlus.Models {
    public abstract class Runner : Object {
        public string title { get; set; }
        public string description { get; set; }
        public Group group { get; set; }
        public bool has_more { get; set; } // TODO Find a better name
        public List<Release> releases;

        public abstract async List<Release> load();
    }
}