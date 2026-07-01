namespace ProtonPlus.Models.Launchers.Runners {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public interface IRunner : Object {
        public abstract string title { get; set; }
        public abstract string description { get; set; }
        public abstract string endpoint { get; set; }
        public abstract Gee.LinkedList<Variant> variants { get; set; }
        public abstract Gee.LinkedList<Launcher> launchers { get; set; }
        public abstract Tools.Basic? create_tool (Group group);
        public abstract async IReleases? request_releases (int page, int limit, out ReturnCode code);
    }
}
