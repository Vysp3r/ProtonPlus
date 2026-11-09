namespace ProtonPlus.Widgets.Main {
    public class SteamRepairBanner : Gtk.Box {
        public signal void guidance_requested (Models.Launchers.Steam launcher);
        private Adw.Banner banner;
        private Models.Launchers.Steam? launcher;
        private ulong diagnostics_handler;
        private Gee.HashMap<string, string> dismissed = new Gee.HashMap<string, string> ();

        public SteamRepairBanner () {
            Object (orientation: Gtk.Orientation.VERTICAL);
            banner = new Adw.Banner ("") { hexpand = true, use_markup = false };
            banner.button_label = _("Learn More");
            banner.button_clicked.connect (() => {
                if (launcher != null && launcher.broken_compatibility_tools.size > 0)
                    guidance_requested (launcher);
            });
            append (banner);
            set_visible (false);
        }

        public void set_launcher (Models.Launcher? selected) {
            detach ();
            launcher = selected as Models.Launchers.Steam;
            if (launcher != null)
                diagnostics_handler = launcher.notify["broken-compatibility-tools"].connect (update);
            update ();
        }

        public void dismiss_for (Models.Launchers.Steam steam) {
            dismissed.set (steam.directory, fingerprint (steam));
            update ();
        }

        private string fingerprint (Models.Launchers.Steam steam) {
            var result = new StringBuilder ();
            foreach (var candidate in steam.broken_compatibility_tools)
                result.append ("%u:%s\n".printf (candidate.appid, candidate.install_path));
            return result.str;
        }

        private void update () {
            var steam = launcher;
            if (steam == null || steam.broken_compatibility_tools.size == 0) {
                if (steam != null)
                    dismissed.unset (steam.directory);
                banner.revealed = false;
                set_visible (false);
                return;
            }
            var candidates = steam.broken_compatibility_tools;
            var title = candidates.size == 1
                ? _("“%s” appears unavailable in Steam (%s)").printf (
                    candidates[0].display_title, steam.get_installation_type_title ())
                : ngettext ("%d tool appears unavailable in Steam (%s)",
                    "%d tools appear unavailable in Steam (%s)", candidates.size).printf (
                    candidates.size, steam.get_installation_type_title ());
            banner.title = title;
            var show = dismissed.get (steam.directory) != fingerprint (steam);
            banner.revealed = show;
            set_visible (show);
        }

        public void detach () {
            if (launcher != null && diagnostics_handler != 0)
                launcher.disconnect (diagnostics_handler);
            diagnostics_handler = 0;
            launcher = null;
            set_visible (false);
        }

        public override void dispose () {
            detach ();
            base.dispose ();
        }
    }
}
