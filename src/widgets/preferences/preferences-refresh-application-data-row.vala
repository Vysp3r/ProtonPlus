namespace ProtonPlus.Widgets.Preferences {
    public class RefreshApplicationDataRow : Adw.ActionRow {
        Gtk.Button refresh_button;
        Adw.Spinner spinner;

        construct {
            refresh_button = new Gtk.Button.from_icon_name ("arrows-rotate-symbolic");
            refresh_button.add_css_class ("flat");
            refresh_button.set_valign (Gtk.Align.CENTER);
            refresh_button.set_tooltip_text (_("Refresh application data"));
            refresh_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Refresh application data"), -1
            );
            refresh_button.clicked.connect (refresh);

            spinner = new Adw.Spinner ();

            set_title (_ ("Refresh application data"));
            set_subtitle (_ ("Refreshes the launchers, tools and games"));
            add_suffix (refresh_button);
        }

        public RefreshApplicationDataRow () {
        }

        void refresh () {
            refresh_button.set_sensitive (false);

            refresh_button.set_child (spinner);

            activate_action ("app.reload", null);

            spinner?.unparent ();

            refresh_button?.set_icon_name ("arrows-rotate-symbolic");
            refresh_button?.set_sensitive (true);
        }
    }
}
