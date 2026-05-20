namespace ProtonPlus.Widgets.Preferences {
    public class DeleteCacheRow : Adw.ActionRow {
        Gtk.Button delete_button;
        Adw.Spinner spinner;

        construct {
            delete_button = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            delete_button.add_css_class ("flat");
            delete_button.add_css_class ("destructive-action");
            delete_button.set_valign (Gtk.Align.CENTER);
            delete_button.clicked.connect (() => delete_cache.begin ());

            spinner = new Adw.Spinner ();

            set_title (_ ("Delete cache"));
            set_subtitle (_ ("Removes all cached information and temporary downloads"));
            add_suffix (delete_button);
        }

        async void delete_cache () {
            delete_button.set_sensitive (false);
            delete_button.set_child (spinner);

            yield Utils.Filesystem.delete_directory (Globals.CACHE_PATH);

            if (!FileUtils.test (Globals.CACHE_PATH, FileTest.IS_DIR)) {
                Utils.Filesystem.create_directory (Globals.CACHE_PATH);
            }

            spinner?.unparent ();
            delete_button?.set_icon_name ("user-trash-symbolic");
            delete_button?.set_sensitive (true);
        }
    }
}
