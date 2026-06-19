namespace ProtonPlus.Models.Launchers.Runners {
    using Gee;
    public interface IRunner {
        public abstract string title { get; set; }
        public abstract string description { get; set; }
        public abstract string endpoint { get; set; }
        public abstract Gee.LinkedList<Variant> variants { get; set; default = new Gee.LinkedList<Variant> (); }
    }
}
