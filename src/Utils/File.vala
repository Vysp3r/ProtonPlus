namespace Utils {
    public class File {
        public static string Extract (string install_location, string tool_name) {
            const int bufferSize = 192000;

            var archive = new Archive.Read ();
            archive.support_format_all ();
            archive.support_filter_all ();

            int flags;
            flags = Archive.ExtractFlags.ACL;
            flags |= Archive.ExtractFlags.PERM;
            flags |= Archive.ExtractFlags.TIME;
            flags |= Archive.ExtractFlags.FFLAGS;

            var ext = new Archive.WriteDisk ();
            ext.set_standard_lookup ();
            ext.set_options (flags);

            if (archive.open_filename (install_location + tool_name + ".tar.gz", bufferSize) != Archive.Result.OK) return "";

            ssize_t r;

            unowned Archive.Entry entry;

            string sourcePath = "";
            bool firstRun = true;

            for ( ;; ) {
                r = archive.next_header (out entry);
                if (r == Archive.Result.EOF) break;
                if (r < Archive.Result.OK) stderr.printf (ext.error_string ());
                if (r < Archive.Result.WARN) return "";
                if (firstRun) {
                    sourcePath = entry.pathname ();
                    firstRun = false;
                }
                entry.set_pathname (install_location + entry.pathname ());
                r = ext.write_header (entry);
                if (r < Archive.Result.OK) stderr.printf (ext.error_string ());
                else if (entry.size () > 0) {
                    r = copy_data (archive, ext);
                    if (r < Archive.Result.WARN) return "";
                }
                r = ext.finish_entry ();
                if (r < Archive.Result.OK) stderr.printf (ext.error_string ());
                if (r < Archive.Result.WARN) return "";

                if (Stores.Main.get_instance ().IsInstallationCancelled) {
                    Delete (install_location + sourcePath);
                    break;
                }
            }

            archive.close ();

            Delete (install_location + tool_name + ".tar.gz");

            return install_location + sourcePath;
        }

        static ssize_t copy_data (Archive.Read ar, Archive.WriteDisk aw) {
            ssize_t r;
            uint8[] buffer;
            Archive.int64_t offset;

            for ( ;; ) {
                r = ar.read_data_block (out buffer, out offset);
                if (r == Archive.Result.EOF) return (Archive.Result.OK);
                if (r < Archive.Result.OK) return (r);
                r = aw.write_data_block (buffer, offset);
                if (r < Archive.Result.OK) {
                    stderr.printf (aw.error_string ());
                    return (r);
                }
            }
        }

        public static void Delete (string path) {
            try {
                var file = GLib.File.new_for_path (path);
                file.trash ();
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public static void Rename (string sourcePath, string destinationPath) {
            GLib.FileUtils.rename (sourcePath, destinationPath);
        }

        public static bool Exists (string path) {
            var file = GLib.File.new_for_path (path);
            return file.query_exists ();
        }

        public static void Write (string path, string content) {
            try {
                var file = GLib.File.new_for_path (path);
                FileOutputStream os = file.create (FileCreateFlags.PRIVATE);
                os.write (content.data);
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public static void CreateDirectory (string path) {
            try {
                var file = GLib.File.new_for_path (path);
                file.make_directory ();
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public static GLib.List<string> ListDirectoryFolders (string path) {
            var folders = new GLib.List<string> ();

            try {
                if (FileUtils.test (path, FileTest.IS_DIR)) {
                    var root = GLib.File.new_for_path (path);

                    var enumerator = root.enumerate_children ("tata", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

                    FileInfo info = null;
                    while ((info = enumerator.next_file ()) != null) {
                        if (info.get_file_type () == FileType.DIRECTORY) {
                            folders.append (info.get_name ());
                        }
                    }
                }
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }

            return folders;
        }
    }
}
