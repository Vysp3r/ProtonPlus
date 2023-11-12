namespace ProtonPlus.Widgets {
    public class StatusBox : Gtk.Box {
        Adw.StatusPage status_page { get; set; }

        construct {
            //
            var header = new Adw.HeaderBar ();
            header.add_css_class ("flat");

            //
            status_page = new Adw.StatusPage ();
            status_page.set_vexpand (true);
            status_page.set_hexpand (true);

            //
            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header);
            toolbar_view.set_content (status_page);

            //
            this.append (toolbar_view);
        }

        public void initialize (string? icon_name, string title, string description) {
            status_page.set_icon_name (icon_name);
            status_page.set_title (title);
            status_page.set_description (description);
        }
    }
}