namespace ProtonPlus.Models.Launchers.Runners {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Base : Object, IRunner {
        public string title { get; set; }
        public string description { get; set; }
        public string endpoint { get; set; }

        public Gee.LinkedList<Variant> variants { get; set; default = new Gee.LinkedList<Variant> (); }
        public Gee.LinkedList<Launcher> launchers { get; set; default = new Gee.LinkedList<Launcher> (); }

        public Base (string title, string description, string endpoint) {
            this.title = title;
            this.description = description;
            this.endpoint = endpoint;
        }
    }
}
