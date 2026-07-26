namespace ProtonPlus.Models {
    public class InstalledToolEntry : Object {
        public string path { get; construct set; }
        public string directory_name { get; construct set; }
        public string internal_title { get; construct set; }
        public string display_title { get; construct set; }
        public string runner_endpoint { get; construct set; }
        public string runner_title { get; construct set; }
        public string tag { get; construct set; }
        public string provider_id { get; construct set; }
        public string tool_id { get; construct set; }
        public string launcher_id { get; construct set; }
        public string variant_id { get; construct set; }
        public string release_id { get; construct set; }

        public bool has_compatibilitytool_vdf { get; construct set; }

        public InstalledToolEntry (
            string path,
            string directory_name,
            string internal_title,
            string display_title,
            string runner_endpoint,
            string runner_title,
            string tag,
            string provider_id,
            string tool_id,
            string launcher_id,
            string variant_id,
            string release_id,
            bool has_compatibilitytool_vdf
        ) {
            Object (
                path: path,
                directory_name: directory_name,
                internal_title: internal_title,
                display_title: display_title,
                runner_endpoint: runner_endpoint,
                runner_title: runner_title,
                tag: tag,
                provider_id: provider_id,
                tool_id: tool_id,
                launcher_id: launcher_id,
                variant_id: variant_id,
                release_id: release_id,
                has_compatibilitytool_vdf: has_compatibilitytool_vdf
            );
        }
    }

    public class Group : Object {
        public string id { get; private set; }
        public string title { get; set; }
        public string description { get; set; }
        public string directory { get; set; }
        public Launcher launcher { get; set; }
        public Gee.LinkedList<Tool> tools { get; set; }

        private Gee.ArrayList<InstalledToolEntry> installed_tool_index = new Gee.ArrayList<InstalledToolEntry> ();

        public signal void installed_tool_index_invalidated ();

        public Group (string title, string description, string directory, Launcher launcher, string id = "unknown") {
            this.id = id;
            this.title = title;
            this.description = description;
            this.directory = directory;
            this.launcher = launcher;

            if (!FileUtils.test (launcher.directory + directory, FileTest.IS_DIR)) {
                Utils.Filesystem.create_directory_async.begin (launcher.directory + directory, null);
            }
        }

        public List<string> get_tool_directories () {
            var directories = new List<string> ();

            try {
                foreach (var directory_path in launcher.get_tool_directories (this)) {
                    var compatibilitytoolvdf_path = "%s/compatibilitytool.vdf".printf (directory_path);

                    if (FileUtils.test (compatibilitytoolvdf_path, FileTest.IS_REGULAR)) {
                        var simple_runner = new Tools.Simple.from_path (directory_path);
                        directories.append (simple_runner.title);
                        continue;
                    }

                    if (!FileUtils.test (directory_path, FileTest.IS_DIR)) {
                        continue;
                    }

                    File directory = File.new_for_path (directory_path);
                    FileEnumerator? enumerator = directory.enumerate_children ("standard::*", FileQueryInfoFlags.NONE, null);

                    if (enumerator != null) {
                        FileInfo? file_info;
                        while ((file_info = enumerator.next_file ()) != null) {
                            if (file_info.get_file_type () != FileType.DIRECTORY)
                            continue;

                            var title = file_info.get_name ();

                            if (title != "LegacyRuntime")
                            directories.append (title);
                        }
                    }
                }
            } catch (Error e) {
                warning (e.message);
            }

            return directories;
        }

        // Installation discovery is intentionally centralized here.  Tool-list
        // filter and sort callbacks call this data repeatedly, so they must not
        // enumerate the filesystem or parse compatibilitytool.vdf themselves.
        public Gee.List<InstalledToolEntry> get_installed_tool_index () {
            return installed_tool_index;
        }

        public void rebuild_installed_tool_index () {
            installed_tool_index.clear ();

            foreach (var directory_root in launcher.get_tool_directories (this)) {
                add_installed_tool_index_entry (directory_root);

                if (!FileUtils.test (directory_root, FileTest.IS_DIR))
                    continue;

                try {
                    File directory = File.new_for_path (directory_root);
                    FileEnumerator? enumerator = directory.enumerate_children ("standard::*", FileQueryInfoFlags.NONE, null);
                    if (enumerator == null)
                        continue;

                    FileInfo? file_info;
                    while ((file_info = enumerator.next_file ()) != null) {
                        if (file_info.get_file_type () != FileType.DIRECTORY)
                            continue;

                        add_installed_tool_index_entry (Path.build_filename (directory_root, file_info.get_name ()));
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            }

        }

        public void invalidate_installed_tool_index () {
            installed_tool_index.clear ();
            installed_tool_index_invalidated ();
        }

        private void add_installed_tool_index_entry (string path) {
            var compatibilitytoolvdf_path = Path.build_filename (path, "compatibilitytool.vdf");
            var has_compatibilitytool_vdf = FileUtils.test (compatibilitytoolvdf_path, FileTest.IS_REGULAR);

            if (!has_compatibilitytool_vdf && !FileUtils.test (path, FileTest.IS_DIR))
                return;

            var directory_name = Path.get_basename (path);
            var internal_title = directory_name;
            var display_title = directory_name;

            if (has_compatibilitytool_vdf) {
                var simple_runner = new Tools.Simple.from_path (path);
                internal_title = simple_runner.internal_title;
                display_title = simple_runner.title;
            }

            var metadata = Utils.Metadata.load (path);
            installed_tool_index.add (new InstalledToolEntry (
                path,
                directory_name,
                internal_title,
                display_title,
                metadata.runner_endpoint,
                metadata.runner_title,
                metadata.tag,
                metadata.provider_id,
                metadata.tool_id,
                metadata.launcher_id,
                metadata.variant_id,
                metadata.release_id,
                has_compatibilitytool_vdf
            ));
        }
    }
}
