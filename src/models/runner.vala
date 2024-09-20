namespace ProtonPlus.Models {
    public abstract class Runner : Object {
        public string title { get; set; }
        public string description { get; set; }
        public Group group { get; set; }
        public List<Release> releases;
        public bool busy { get; set; }

        public abstract async List<Release> load();
    }
}