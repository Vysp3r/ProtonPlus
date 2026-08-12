namespace ProtonPlus.Widgets.Tools {
    public interface ReleaseRowJobSignalTarget : Object {
        public abstract void release_row_job_state_changed ();
        public abstract void release_row_job_step_changed ();
        public abstract void release_row_job_progress_changed ();
        public abstract void release_row_job_canceled_changed ();
        public abstract void release_row_job_variant_changed ();
        public abstract void release_row_job_release_changed ();
    }

    /// Owns every long-lived InstallJob subscription used by a release row so
    /// a removed row can sever background callbacks in one disposal step.
    public class ReleaseRowJobSignalBinding : Object {
        WeakRef job_ref;
        WeakRef target_ref;
        ulong state_handler = 0;
        ulong step_handler = 0;
        ulong progress_handler = 0;
        ulong canceled_handler = 0;
        ulong variant_handler = 0;
        ulong release_handler = 0;

        public bool connected { get; private set; default = true; }

        public ReleaseRowJobSignalBinding (
            Services.InstallJob job,
            ReleaseRowJobSignalTarget target
        ) {
            job_ref = WeakRef (job);
            target_ref = WeakRef (target);
            state_handler = job.notify["state"].connect (state_changed);
            step_handler = job.notify["step"].connect (step_changed);
            progress_handler = job.progress_updated.connect (progress_changed);
            canceled_handler = job.notify["canceled"].connect (canceled_changed);
            variant_handler = job.notify["selected-variant-name"].connect (
                variant_changed
            );
            release_handler = job.notify["release"].connect (release_changed);
        }

        void state_changed () {
            var target = target_ref.get () as ReleaseRowJobSignalTarget;
            target?.release_row_job_state_changed ();
        }

        void step_changed () {
            var target = target_ref.get () as ReleaseRowJobSignalTarget;
            target?.release_row_job_step_changed ();
        }

        void progress_changed () {
            var target = target_ref.get () as ReleaseRowJobSignalTarget;
            target?.release_row_job_progress_changed ();
        }

        void canceled_changed () {
            var target = target_ref.get () as ReleaseRowJobSignalTarget;
            target?.release_row_job_canceled_changed ();
        }

        void variant_changed () {
            var target = target_ref.get () as ReleaseRowJobSignalTarget;
            target?.release_row_job_variant_changed ();
        }

        void release_changed () {
            var target = target_ref.get () as ReleaseRowJobSignalTarget;
            target?.release_row_job_release_changed ();
        }

        public void disconnect_handlers () {
            if (!connected)
                return;
            disconnect_handler (ref state_handler);
            disconnect_handler (ref step_handler);
            disconnect_handler (ref progress_handler);
            disconnect_handler (ref canceled_handler);
            disconnect_handler (ref variant_handler);
            disconnect_handler (ref release_handler);
            connected = false;
        }

        void disconnect_handler (ref ulong handler) {
            if (handler == 0)
                return;
            var job = job_ref.get () as Services.InstallJob;
            job?.disconnect (handler);
            handler = 0;
        }

        public override void dispose () {
            disconnect_handlers ();
            base.dispose ();
        }
    }

    public enum ReleaseRowPrimaryAction {
        NONE,
        INSTALL,
        RETRY,
        PROGRESS
    }

    public enum ReleaseRowRetryAction {
        NONE,
        INSTALL,
        UPDATE
    }

    /// UI-free mapping from the observable installation lifecycle and row
    /// capabilities to the controls that a release row may present.
    public class ReleaseRowPresentation : Object {
        public ReleaseRowPrimaryAction primary_action { get; private set; }
        public bool installed { get; private set; }
        public bool recommended { get; private set; }
        public bool in_use { get; private set; }
        public bool update_available { get; private set; }
        public bool unavailable { get; private set; }
        public bool busy { get; private set; }
        public bool progress_indeterminate { get; private set; }
        public bool show_cancel { get; private set; }
        public bool cancel_enabled { get; private set; }
        public bool show_update_action { get; private set; }
        public bool show_open_folder { get; private set; }
        public bool show_delete { get; private set; }

        public bool show_menu {
            get {
                return true;
            }
        }

        public static ReleaseRowPresentation evaluate (
            Services.InstallJob.State state,
            Services.InstallJob.Step step,
            bool supports_update_check,
            bool has_installed_directory,
            bool cancellation_requested = false,
            bool recommended = false,
            bool in_use = false,
            bool action_available = true,
            ReleaseRowRetryAction retry_action = ReleaseRowRetryAction.NONE
        ) {
            var result = new ReleaseRowPresentation ();
            result.installed = state == Services.InstallJob.State.UP_TO_DATE ||
                state == Services.InstallJob.State.UPDATE_AVAILABLE;
            result.recommended = recommended;
            result.in_use = in_use;
            result.update_available =
                state == Services.InstallJob.State.UPDATE_AVAILABLE;
            result.unavailable = !action_available;
            result.busy = state == Services.InstallJob.State.BUSY_INSTALLING ||
                state == Services.InstallJob.State.BUSY_UPDATING ||
                state == Services.InstallJob.State.BUSY_REMOVING;

            if (result.busy) {
                result.primary_action = ReleaseRowPrimaryAction.PROGRESS;
            } else if (!action_available) {
                result.primary_action = ReleaseRowPrimaryAction.NONE;
            } else if (retry_action == ReleaseRowRetryAction.INSTALL) {
                result.primary_action = ReleaseRowPrimaryAction.RETRY;
            } else {
                switch (state) {
                case Services.InstallJob.State.NOT_INSTALLED:
                    result.primary_action = ReleaseRowPrimaryAction.INSTALL;
                    break;
                default:
                    result.primary_action = ReleaseRowPrimaryAction.NONE;
                    break;
                }
            }

            result.progress_indeterminate = result.busy &&
                step != Services.InstallJob.Step.DOWNLOADING;

            // Install/update workflows own a cancellable. Removal currently
            // does not, so presenting Cancel while removing would be unsafe.
            result.show_cancel = state == Services.InstallJob.State.BUSY_INSTALLING ||
                state == Services.InstallJob.State.BUSY_UPDATING;
            result.cancel_enabled = result.show_cancel && !cancellation_requested;

            if (!result.busy) {
                result.show_update_action = result.installed &&
                    action_available && (
                        retry_action == ReleaseRowRetryAction.UPDATE ||
                        state == Services.InstallJob.State.UPDATE_AVAILABLE ||
                        (state == Services.InstallJob.State.UP_TO_DATE &&
                            supports_update_check)
                    );
                result.show_open_folder = result.installed &&
                    has_installed_directory;
                result.show_delete = result.installed;
            }

            return result;
        }
    }
}
