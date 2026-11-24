namespace ProtonPlus.Widgets.Preferences {
    using ProtonPlus.Utils;
    public class DeleteCacheRow : Adw.ActionRow {
        Gtk.Button delete_button;
        Gtk.Spinner spinner;

        construct {
            delete_button = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            delete_button.add_css_class ("flat");
            delete_button.add_css_class ("destructive-action");
            delete_button.set_valign (Gtk.Align.CENTER);
            delete_button.set_tooltip_text (_("Delete cache"));
            delete_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Delete cache"), -1
            );
            delete_button.clicked.connect (() => delete_cache.begin ());

            spinner = new Gtk.Spinner ();

            set_title (_ ("Delete cache"));
            set_subtitle (_ ("Removes all cached information and temporary downloads"));
            add_suffix (delete_button);
            set_activatable_widget (delete_button);
        }

        async void delete_cache () {
            delete_button.set_sensitive (false);
            delete_button.set_child (spinner);
            spinner.start ();

            if (!yield CacheManager.clear_cache ())
                warning ("Could not clear and recreate the cache directory.");

            spinner.stop ();
            delete_button.set_icon_name ("user-trash-symbolic");
            delete_button.set_sensitive (true);
        }
    }
}
