namespace ProtonPlus.Models.Releases {
    public abstract class Upgrade<R>: Release<R> {
        public async bool upgrade () {
            state = State.BUSY_UPGRADING;

            var upgrade_success = yield _start_upgrade ();

            refresh_state ();

            return upgrade_success;
        }

        protected abstract async bool _start_upgrade ();
    }
}