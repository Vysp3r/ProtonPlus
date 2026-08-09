namespace ProtonPlus.Widgets.Main {
    using ProtonPlus.Models;

    public class SteamRestartReviewDialog : Adw.Dialog {
        public signal void restart_requested (SteamRestartTarget target);

        public SteamRestartReviewDialog (Gee.List<SteamRestartTargetSummary> targets) {
            Object (title: _ ("Restart Steam?"));
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                margin_top = 24, margin_bottom = 24, margin_start = 24, margin_end = 24
            };
            content.append (new Gtk.Label (_ ("Each Steam installation must be restarted separately. Save your progress and close any running games before continuing. In SteamOS Gaming Mode, Steam, running games, and ProtonPlus will close while Steam restarts.")) {
                wrap = true, xalign = 0
            });
            var group = new Adw.PreferencesGroup ();
            foreach (var summary in targets) {
                var row = new Adw.ActionRow () {
                    title = summary.target.display_name,
                    subtitle = ngettext ("%u pending change", "%u pending changes", summary.pending_count).printf (summary.pending_count)
                };
                var button = new Gtk.Button.with_label (_ ("Restart"));
                button.add_css_class ("suggested-action");
                button.clicked.connect (() => { restart_requested (summary.target); });
                row.add_suffix (button);
                group.add (row);
            }
            content.append (group);
            var later = new Gtk.Button.with_label (_ ("Later")) { halign = Gtk.Align.END };
            later.clicked.connect (() => { close (); });
            content.append (later);
            set_default_widget (later);
            set_child (content);
        }
    }
}
