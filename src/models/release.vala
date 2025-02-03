namespace ProtonPlus.Models {
    public abstract class Release<R>: Object {
        public Runner runner { get; set; }
        public string title { get; set; }
        public string displayed_title { get; set; }
        public string description { get; set; }
        public string release_date { get; set; }
        public string download_url { get; set; }
        public string page_url { get; set; }
        public bool canceled { get; set; }
        public string progress { get; set; }
        public signal void send_message (string message);

        public State state { get; set; }
        public enum State {
            NOT_INSTALLED,
            UPDATE_AVAILABLE,
            UP_TO_DATE,
            BUSY_INSTALLING,
            BUSY_REMOVING,
            BUSY_UPGRADING,
        }

        construct {
            notify["state"].connect (state_changed);
        }

        void state_changed () {
            switch (state) {
            case State.BUSY_INSTALLING:
                send_message (_("The installation of %s has begun.").printf (title));
                break;
            case State.BUSY_REMOVING:
                send_message (_("The removal of %s has begun.").printf (title));
                break;
            case State.BUSY_UPGRADING:
                send_message (_("The upgrade of %s has begun.").printf (title));
                break;
            default:
                break;
            }
        }

        public async bool install () {
            var busy_upgrading = state == State.BUSY_UPGRADING;

            if (!busy_upgrading)
                state = State.BUSY_INSTALLING;

            // Attempt the installation.
            var install_success = yield _start_install ();

            if (!install_success) {
                yield remove (new Models.Parameters ()); // Refreshes install state too.

                if (!busy_upgrading)
                    send_message (_("An unexpected error occurred while installing %s.").printf (title));
            } else if (!busy_upgrading)
                send_message (_("The installation of %s is complete.").printf (title));

            if (!busy_upgrading)
                refresh_state (); // Force UI state refresh.

            return install_success;
        }

        protected abstract async bool _start_install ();

        public async bool remove (R parameters) {
            var busy_upgrading_or_instaling = state == State.BUSY_UPGRADING || state == State.BUSY_INSTALLING;

            if (!busy_upgrading_or_instaling)
                state = State.BUSY_REMOVING;

            // Attempt the removal.
            var remove_success = yield _start_remove (parameters);

            if (!busy_upgrading_or_instaling) {
                send_message ((remove_success ? _("The removal of %s is complete.") : _("An unexpected error occurred while removing %s.")).printf (title));
                refresh_state (); // Force UI state refresh.
            }

            return remove_success;
        }

        protected abstract async bool _start_remove (R parameters);

        protected abstract void refresh_state ();
    }
}