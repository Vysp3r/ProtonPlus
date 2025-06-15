namespace ProtonPlus.Widgets {
	public class StatusBox : Gtk.Box {
		Adw.ToolbarView toolbar_view { get; set; }
		Adw.HeaderBar header_bar { get; set; }
		Adw.StatusPage status_page { get; set; }

		construct {
			header_bar = new Adw.HeaderBar ();
			header_bar.add_css_class ("flat");

			status_page = new Adw.StatusPage ();
			status_page.set_vexpand (true);
			status_page.set_hexpand (true);

			toolbar_view = new Adw.ToolbarView ();
			toolbar_view.add_top_bar (header_bar);
			toolbar_view.set_content (status_page);

			append (toolbar_view);
		}

		public void initialize (string? icon_name, string title, string description) {
			status_page.set_icon_name (icon_name);
			status_page.set_title (title);
			status_page.set_description (description);
		}
	}
}
