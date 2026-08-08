namespace ProtonPlus.Services {
    /// The specialized part of an installation.  The service owns operation
    /// registration and finalization; workflows own their filesystem and
    /// tool-specific transactions.
    public abstract class InstallationWorkflow : Object {
        public abstract ReturnCode validate_install (InstallJob job, bool replace_existing);
        public abstract async ReturnCode install (InstallJob job, bool replace_existing);
        public abstract async ReturnCode update (InstallJob job, InstallationOperationCoordinator coordinator);
        public abstract async ReturnCode remove (InstallJob job);
        public abstract void refresh_state (InstallJob job);

        public virtual void finalize_install_success (InstallJob job) {}
        public virtual void finalize_removal_success (InstallJob job) {}
    }

    /// A deliberately small callback through which an update workflow asks the
    /// application coordinator to run its replacement download transaction.
    /// This keeps DownloadManager, CacheManager, and completion history in one
    /// place without making workflows depend on InstallationService directly.
    public interface InstallationOperationCoordinator : Object {
        public abstract async ReturnCode install_for_update (InstallJob job);
    }

    /* Workflows call this only after their top-level update transaction has
     * completed. Test coordinators need not implement lifecycle recording. */
    public interface InstallationLifecycleRecorder : Object {
        public abstract void record_completed_update (InstallJob job);
    }
}
