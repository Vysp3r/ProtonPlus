namespace ProtonPlus.Models {
    public class DownloadManager : GLib.Object {
        private static DownloadManager _instance;
        public static DownloadManager instance {
            get {
                if (_instance == null) {
                    _instance = new DownloadManager ();
                }
                return _instance;
            }
        }

        public Gee.ArrayList<BaseRelease> active_downloads { get; private set; }
        public Gee.ArrayList<BaseRelease> history { get; private set; }

        public bool is_downloading (BaseRelease release) {
            return get_active_download (release) != null;
        }

        public BaseRelease? get_active_download (BaseRelease release) {
            foreach (var active_download in active_downloads) {
                if (active_download.download_url == release.download_url && active_download.title == release.title) {
                    return active_download;
                }
            }
            return null;
        }

        public signal void download_added (BaseRelease release);
        public signal void download_removed (BaseRelease release);
        public signal void download_finished (BaseRelease release, bool success);

        private DownloadManager () {
            active_downloads = new Gee.ArrayList<BaseRelease> ();
            history = new Gee.ArrayList<BaseRelease> ();

            load_history ();

            if (Globals.SETTINGS != null) {
                Globals.SETTINGS.changed["save-history"].connect (() => {
                    if (!Globals.SETTINGS.get_boolean ("save-history")) {
                        clear_history ();
                    }
                });
            }
        }

        public void add_download (BaseRelease release) {
            if (!is_downloading (release)) {
                for (int i = 0; i < history.size; i++) {
                    var history_release = history.get (i);
                    if (history_release.title == release.title) {
                        history.remove_at (i);
                        save_history ();
                        break;
                    }
                }

                active_downloads.add (release);
                download_added (release);
            }
        }

        public void remove_download (BaseRelease release) {
            if (active_downloads.contains (release)) {
                active_downloads.remove (release);
                download_removed (release);
            }
        }

        public void add_to_history (BaseRelease release, bool success) {
            if (!history.contains (release)) {
                history.add (release);
                download_finished (release, success);
                save_history ();
            }
        }

        public void clear_history () {
            history.clear ();

            var history_file = Path.build_filename (Environment.get_user_config_dir (), "ProtonPlus", "history.json");
            if (FileUtils.test (history_file, FileTest.EXISTS))
            FileUtils.remove (history_file);

            save_history ();
        }

        private void save_history () {
            if (Globals.SETTINGS != null && !Globals.SETTINGS.get_boolean ("save-history"))
            return;

            var root_array = new Json.Array ();
            foreach (var release in history) {
                var release_object = new Json.Object ();
                release_object.set_string_member ("title", release.title);
                release_object.set_string_member ("displayed_title", release.displayed_title != null ? release.displayed_title : "");
                release_object.set_string_member ("icon_path", release.runner.group.launcher.icon_path != null ? release.runner.group.launcher.icon_path : "");
                release_object.set_boolean_member ("is_finished", release.is_finished);
                release_object.set_boolean_member ("install_success", release.install_success);
                release_object.set_boolean_member ("canceled", release.canceled);
                root_array.add_object_element (release_object);
            }

            var root_node = new Json.Node (Json.NodeType.ARRAY);
            root_node.set_array (root_array);

            var generator = new Json.Generator ();
            generator.set_root (root_node);
            generator.set_pretty (true);

            var history_file = Path.build_filename (Globals.CONFIG_PATH, "history.json");
            try {
                generator.to_file (history_file);
            } catch (Error e) {
                warning ("Failed to save download history: %s".printf (e.message));
            }
        }

        private void load_history () {
            if (Globals.SETTINGS != null && !Globals.SETTINGS.get_boolean ("save-history"))
            return;

            var history_file = Path.build_filename (Environment.get_user_config_dir (), "ProtonPlus", "history.json");
            if (!FileUtils.test (history_file, FileTest.EXISTS))
            return;

            var parser = new Json.Parser ();
            try {
                parser.load_from_file (history_file);
            } catch (Error e) {
                warning ("Failed to load download history: %s".printf (e.message));
                return;
            }

            var root_node = parser.get_root ();
            if (root_node == null || root_node.get_node_type () != Json.NodeType.ARRAY)
            return;

            var root_array = root_node.get_array ();
            for (var i = 0; i < root_array.get_length (); i++) {
                var release_object = root_array.get_object_element (i);
                var title = release_object.get_string_member ("title");
                var displayed_title = release_object.get_string_member ("displayed_title");
                var icon_path = release_object.get_string_member ("icon_path");
                var is_finished = release_object.get_boolean_member ("is_finished");
                var install_success = release_object.get_boolean_member ("install_success");
                var canceled = release_object.get_boolean_member ("canceled");

                var release = new Releases.History (title, displayed_title != "" ? displayed_title : null, icon_path, is_finished, install_success, canceled);
                history.add (release);
            }
        }
    }
}
