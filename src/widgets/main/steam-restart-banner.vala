namespace ProtonPlus.Widgets.Main {
    using ProtonPlus.Models;

    /* Adw.Banner is sealed, so this small wrapper owns its presentation while
     * keeping the reusable component explicit. */
    public class SteamRestartBanner : Gtk.Box {
        public signal void restart_requested ();
        private Adw.Banner banner;

        public SteamRestartBanner () {
            Object (orientation: Gtk.Orientation.VERTICAL);
            banner = new Adw.Banner (_ ("Restart Steam to apply changes"));
            banner.set_button_label (_ ("Restart Steam"));
            banner.button_clicked.connect (() => { restart_requested (); });
            append (banner);
            set_visible (false);
        }

        public void show_pending (SteamRestartBannerState state) {
            banner.set_title (state.title);
            banner.set_button_label (_ ("Restart Steam"));
            set_visible (state.visible);
            banner.set_revealed (state.visible);
        }

        public void show_progress (SteamRestartOperationState state) {
            var title = SteamRestartPresentation.progress_title (state);
            if (title == "")
                return;
            banner.set_title (title);
            banner.set_button_label (null);
            set_visible (true);
            banner.set_revealed (true);
        }
    }
}
