namespace ProtonPlus.Models.Releases {
    public abstract class Upgrade<R>: Release<R> {
        public async bool upgrade () {
            state = State.BUSY_UPGRADING;

            var upgrade_success = yield _start_upgrade ();

            send_message ((upgrade_success ? _("The upgrade of %s is complete.") : _("An unexpected error occurred while upgrading %s.")).printf (title));

            refresh_state ();

            return upgrade_success;
        }

        protected abstract async bool _start_upgrade ();
    }
}