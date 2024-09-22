namespace ProtonPlus.Models.Releases {
    public abstract class Upgrade : Release {
        public async bool upgrade () {
            state = State.BUSY_UPGRADING;

            var upgrade_success = yield _start_upgrade ();

            if (upgrade_success)
                send_message (_("The upgrade of %s is complete.").printf (title));
            else
                send_message (_("An unexpected error occurred while upgrading %s."));

            return upgrade_success;
        }

        protected abstract async bool _start_upgrade ();
    }
}