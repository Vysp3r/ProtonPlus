namespace Widgets {
    public class ProtonMessageDialog : Adw.MessageDialog {
        public enum MessageDialogType {
            NO_YES,
            OK
        }

        public delegate void ResponseCallback (string response);

        public ProtonMessageDialog (Gtk.Window window, string? heading, string? body, MessageDialogType type, ResponseCallback? responseCallback) {
            set_transient_for (window);
            if (heading != null) set_heading (heading);
            if (body != null) set_body (body);

            switch (type) {
            case MessageDialogType.NO_YES:
                setupNoYes ();
                break;
            case MessageDialogType.OK:
            default:
                setupOk ();
                break;
            }

            if (responseCallback != null) response.connect ((response) => responseCallback (response));

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
