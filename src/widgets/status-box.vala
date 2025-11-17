namespace ProtonPlus.Widgets {
	public class StatusBox : Gtk.Box {
		Adw.ToolbarView toolbar_view { get; set; }
		Adw.HeaderBar header_bar { get; set; }
		Gtk.Button report_button { get; set; }
		Adw.StatusPage status_page { get; set; }

		public StatusBox () {
			header_bar = new Adw.HeaderBar ();
			header_bar.add_css_class ("flat");

			report_button = new Gtk.Button.with_label ("Report");
			report_button.set_halign (Gtk.Align.CENTER);
			report_button.set_hexpand (false);
			report_button.clicked.connect (report_button_clicked);

			status_page = new Adw.StatusPage ();
			status_page.set_vexpand (true);
			status_page.set_hexpand (true);
			status_page.set_child (report_button);
			
			toolbar_view = new Adw.ToolbarView ();
			toolbar_view.add_top_bar (header_bar);
			toolbar_view.set_content (status_page);

			append (toolbar_view);
		}

		public void initialize (string? icon_name, string title, string description, bool error = false) {
			status_page.set_icon_name (icon_name);
			status_page.set_title (title);
			status_page.set_description (description);

			report_button.set_visible (error);
		}

		void report_button_clicked () {
			activate_action ("app.report", null);
		}
	}
}
