namespace Windows.Notifications {
    public class Main : Gtk.Widget {
        Adw.StatusPage statusPage;

        public Main () {
            var layout = new Gtk.BinLayout ();
            set_layout_manager (layout);

            statusPage = new Adw.StatusPage ();
            statusPage.set_title (_("Notifications"));
            statusPage.set_description (_("This page is a work in progress."));
            statusPage.set_icon_name ("application-rss+xml-symbolic");
            statusPage.set_parent (this);
        }
    }
}
