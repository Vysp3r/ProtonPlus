namespace ProtonPlus.Providers.Sources {
    // Each remote host has a real implementation of this contract.  The
    // definition supplies data only; source adapters own transport and JSON
    // conversion and return canonical catalog models.
    public interface ReleaseSource : Object {
        public abstract async Models.Tools.ReleasePageResult fetch_page (
            Models.Providers.ProviderDefinition definition,
            int requested_page,
            int limit
        );
    }
}
