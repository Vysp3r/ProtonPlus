namespace ProtonPlus.Models {
    public abstract class Release : Object {
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
    }
}