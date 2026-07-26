namespace ProtonPlus.Providers.Sources {
    // Each remote host has a real implementation of this contract.  The
    // definition supplies data only; source adapters own transport and JSON
    // conversion and return canonical catalog models.
    public interface ReleaseSource : Object {
        public abstract async Models.Tools.ReleasePage? fetch_page (
            Models.Providers.ProviderDefinition definition,
            int requested_page,
            int limit,
            out ReturnCode code
        );
    }
}
