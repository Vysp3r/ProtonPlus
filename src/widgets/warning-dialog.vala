namespace ProtonPlus.Widgets {
    public class WarningDialog : Adw.AlertDialog {
        public WarningDialog (string heading, string body) {
            set_heading (heading);
            set_body (body);

			add_response("ok", _("OK"));
			set_response_appearance ("ok", Adw.ResponseAppearance.DEFAULT);
        }
    }
}