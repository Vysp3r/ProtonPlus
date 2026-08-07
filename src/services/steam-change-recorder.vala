namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    /* Installation code records a completed durable change without owning a
     * session observer, state store, or restart orchestrator. */
    public interface SteamChangeRecorder : Object {
        public abstract SteamRestartRecordResult record (SteamChangeReceipt receipt);
    }
}
