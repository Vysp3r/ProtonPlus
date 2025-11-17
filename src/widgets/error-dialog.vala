namespace ProtonPlus.Widgets {
    public class ErrorDialog : Adw.AlertDialog {
        public ErrorDialog (string heading, string body) {
            set_heading (heading);
            set_body (body);

			add_response("report", _("Report"));
			set_response_appearance ("report", Adw.ResponseAppearance.SUGGESTED);

			add_response("ok", _("OK"));
			set_response_appearance ("ok", Adw.ResponseAppearance.DEFAULT);

			response.connect ((response) => {
			    if (response == "report")
				    activate_action ("app.report", null);
			});
        }
    }
}