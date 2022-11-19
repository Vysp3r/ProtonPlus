namespace ProtonPlus.Manager {
    public class File {
        public static void Extract (string install_location, string launcher_name, string tool_name) {
            Archive.Read archive = new Archive.Read ();
            archive.support_format_all ();
            archive.support_filter_all ();

            int flags;
            flags = Archive.ExtractFlags.ACL;
            flags |= Archive.ExtractFlags.PERM;
            flags |= Archive.ExtractFlags.TIME;
            flags |= Archive.ExtractFlags.FFLAGS;

            Archive.WriteDisk ext = new Archive.WriteDisk ();
            ext.set_standard_lookup ();
            ext.set_options (flags);

            if (archive.open_filename (install_location + tool_name + ".tar.gz", 1920000) != Archive.Result.OK) return;

            ssize_t r;

            unowned Archive.Entry entry;

            int bob = 0;
            string test = "";

            for ( ;; ) {
                r = archive.next_header (out entry);
                if (r == Archive.Result.EOF) break;
                if (r < Archive.Result.WARN) break;
                entry.set_pathname (install_location + entry.pathname ());
                if(bob++ == 0){
                    test = entry.pathname ();
                }
                r = ext.write_header (entry);
                if (entry.size () > 0) {
                    r = copy_data (archive, ext);
                    if (r < Archive.Result.WARN) break;
                }
                r = ext.finish_entry ();
                if (r < Archive.Result.WARN) break;
            }

            archive.close ();

            GLib.File file = GLib.File.new_for_path (install_location + tool_name + ".tar.gz");
            file.delete ();

            GLib.File fileSource = GLib.File.new_for_path (test);
            GLib.File fileDest = GLib.File.new_for_path (install_location + launcher_name + " | " + tool_name);
            fileSource.move(fileDest, FileCopyFlags.NONE, null, null);

            ProtonPlus.Stores.Threads store = ProtonPlus.Stores.Threads.instance ();
            store.ProgressBarDone = true;
        }

        private static ssize_t copy_data (Archive.Read ar, Archive.WriteDisk aw) {
            ssize_t r;
            uint8[] buffer;
            Archive.int64_t offset;

            for ( ;; ) {
                r = ar.read_data_block (out buffer, out offset);
                if (r == Archive.Result.EOF) return (Archive.Result.OK);
                if (r < Archive.Result.OK) return (r);
                r = aw.write_data_block (buffer, offset);
                if (r < Archive.Result.OK) return (r);
            }
        }
    }
}
