namespace ProtonPlus.Providers.Sources {
    using ProtonPlus.Models.Launchers.Runners;
    public interface IRequest {
        public async abstract IReleases? request (IRunner runner, int page = 1, int limit = 25);
    }
}
