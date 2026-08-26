namespace ProtonPlus.Widgets.Main {
    using ProtonPlus.Models;

    /* Diagnostic-only, like SteamRestartBanner: Steam's own state can claim a
     * compatibility tool or runtime is fully installed while nothing usable
     * is on disk. ProtonPlus never rewrites Steam's install state to "fix"
     * this; it only explains the corruption and how to recover it. */
    public class SteamRepairBanner : Gtk.Box {
        public signal void guidance_requested ();
        private Adw.Banner banner;

        public SteamRepairBanner () {
            Object (orientation: Gtk.Orientation.VERTICAL);
            banner = new Adw.Banner ("");
            banner.set_button_label (_ ("How to Fix"));
            banner.button_clicked.connect (() => { guidance_requested (); });
            append (banner);
            set_visible (false);
        }

        public void show_for (Gee.List<SteamRuntimeRepairCandidate> candidates) {
            if (candidates.size == 0) {
                set_visible (false);
                banner.set_revealed (false);
                return;
            }

            banner.set_title (candidates.size == 1
                ? _ ("“%s” appears broken in Steam").printf (candidates[0].display_title)
                : _ ("%d Steam compatibility tools appear broken").printf (candidates.size));
            set_visible (true);
            banner.set_revealed (true);
        }
    }
}
