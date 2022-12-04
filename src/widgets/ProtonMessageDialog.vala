namespace ProtonPlus.Widgets {
    public class ProtonMessageDialog : Adw.MessageDialog {
        public enum MessageDialogType {
            NO_YES,
            OK
        }

        public delegate void ResponseCallback (string response);

        public ProtonMessageDialog (Gtk.Window window, string? heading, string? body, MessageDialogType type, ResponseCallback test) {
            set_transient_for (window);
            set_heading (heading);
            set_body (body);

            switch (type) {
            case MessageDialogType.NO_YES:
                setupNoYes ();
                break;
            case MessageDialogType.OK:
            default:
                setupOk ();
                break;
            }

            response.connect ((response) => test (response));

            show ();
        }

        void setupNoYes () {
            add_response ("no", "No");
            set_response_appearance ("no", Adw.ResponseAppearance.SUGGESTED);
            add_response ("yes", "Yes");
            set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);
        }

        void setupOk () {
            add_response ("ok", "Ok");
            set_response_appearance ("ok", Adw.ResponseAppearance.SUGGESTED);
        }
    }
}
