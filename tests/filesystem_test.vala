namespace AppTests.FilesystemTest {
    using GLib;

    [CCode (cname = "flock", cheader_filename = "sys/file.h")]
    private static extern int flock (int fd, int operation);

    public void register_tests () {
        Test.add_func ("/filesystem/cache-operation-cross-process-lock", test_cache_operation_lock);
        Test.add_func ("/filesystem/delete-nested-directory", test_delete_nested_directory);
        Test.add_func ("/filesystem/delete-root-symlink-preserves-target", test_delete_root_symlink_preserves_target);
        Test.add_func ("/filesystem/clear-cache-root-symlink-preserves-target", test_clear_cache_root_symlink_preserves_target);
        Test.add_func ("/filesystem/copy-preserves-symlinks", test_copy_preserves_symlinks);
        Test.add_func ("/filesystem/move-conflict-completes", test_move_conflict_completes);
        Test.add_func ("/filesystem/extract-through-symlinked-ancestor", test_extract_through_symlinked_ancestor);
        Test.add_func ("/filesystem/extract-rejects-archive-symlink-traversal", test_extract_rejects_archive_symlink_traversal);
        Test.add_func ("/filesystem/extract-canonicalization-failure-is-clean", test_extract_canonicalization_failure_is_clean);
    }

    private void test_cache_operation_lock () {
        if (Test.subprocess ()) {
            var root = Environment.get_variable ("PROTONPLUS_TEST_CACHE_ROOT");
            assert (root != null);
            int fd = Posix.open (root + ".downloads.lock", Posix.O_RDWR);
            assert (fd >= 0);
            var acquired = flock (fd, 2 | 4) == 0;
            assert (acquired == (Environment.get_variable ("PROTONPLUS_TEST_CACHE_UNLOCKED") == "1"));
            Posix.close (fd);
            return;
        }
        var loop = new MainLoop ();
        cache_operation_lock_async.begin ((obj, res) => {
            cache_operation_lock_async.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private async void cache_operation_lock_async () {
        var root = create_temp_directory ();
        var previous = ProtonPlus.Globals.CACHE_PATH;
        ProtonPlus.Globals.CACHE_PATH = Path.build_filename (root, "cache");
        Environment.set_variable ("PROTONPLUS_TEST_CACHE_ROOT", ProtonPlus.Globals.CACHE_PATH, true);
        Environment.unset_variable ("PROTONPLUS_TEST_CACHE_UNLOCKED");
        try {
            var first = yield ProtonPlus.Utils.CacheManager.begin_cache_operation ();
            var second = yield ProtonPlus.Utils.CacheManager.begin_cache_operation ();
            Test.trap_subprocess (null, 5000000, TestSubprocessFlags.DEFAULT);
            Test.trap_assert_passed ();
            first.release ();
            Test.trap_subprocess (null, 5000000, TestSubprocessFlags.DEFAULT);
            Test.trap_assert_passed ();
            second.release ();
            second.release (); // Idempotent release must not decrement another operation.
            Environment.set_variable ("PROTONPLUS_TEST_CACHE_UNLOCKED", "1", true);
            Test.trap_subprocess (null, 5000000, TestSubprocessFlags.DEFAULT);
            Test.trap_assert_passed ();

            // Waiting for another process's clear must remain cancellable.
            int fd = Posix.open (ProtonPlus.Globals.CACHE_PATH + ".downloads.lock", Posix.O_RDWR);
            assert (fd >= 0 && flock (fd, 2 | 4) == 0);
            var cancellable = new Cancellable ();
            Timeout.add (20, () => { cancellable.cancel (); return Source.REMOVE; });
            bool cancelled = false;
            try {
                yield ProtonPlus.Utils.CacheManager.begin_cache_operation (cancellable);
            } catch (IOError.CANCELLED e) { cancelled = true; }
            assert (cancelled);
            Posix.close (fd);
            assert (yield ProtonPlus.Utils.CacheManager.clear_cache ());
        } catch (Error e) { error ("%s", e.message); }
        Environment.unset_variable ("PROTONPLUS_TEST_CACHE_ROOT");
        Environment.unset_variable ("PROTONPLUS_TEST_CACHE_UNLOCKED");
        ProtonPlus.Globals.CACHE_PATH = previous;
        assert (yield ProtonPlus.Utils.Filesystem.delete_directory (root));
    }

    private string create_temp_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-filesystem-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private bool delete_directory (string path) {
        var loop = new MainLoop ();
        bool deleted = false;

        ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, result) => {
            assert (obj == null);
            deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (result);
            loop.quit ();
        });
        loop.run ();

        return deleted;
    }

    private bool copy_directory (string source, string destination) {
        var loop = new MainLoop ();
        bool copied = false;

        ProtonPlus.Utils.Filesystem.copy_directory.begin (source, destination, (obj, result) => {
            assert (obj == null);
            copied = ProtonPlus.Utils.Filesystem.copy_directory.end (result);
            loop.quit ();
        });
        loop.run ();

        return copied;
    }

    private bool clear_cache () {
        var loop = new MainLoop ();
        bool cleared = false;

        ProtonPlus.Utils.CacheManager.clear_cache.begin ((obj, result) => {
            assert (obj == null);
            cleared = ProtonPlus.Utils.CacheManager.clear_cache.end (result);
            loop.quit ();
        });
        loop.run ();

        return cleared;
    }

    private string? extract (string install_location, string tool_name, string extension) {
        var loop = new MainLoop ();
        string? extracted = null;

        ProtonPlus.Utils.Filesystem.extract.begin (
            install_location, tool_name, extension, new Cancellable (), (obj, result) => {
                assert (obj == null);
                extracted = ProtonPlus.Utils.Filesystem.extract.end (result);
                loop.quit ();
            }
        );
        loop.run ();

        return extracted;
    }

    private void add_archive_directory (Archive.Write archive, string path) {
        var entry = new Archive.Entry (archive);
        entry.set_pathname (path);
        entry.set_filetype (Archive.FileType.IFDIR);
        entry.set_perm ((Archive.FileMode) 0755);
        entry.set_size (0);
        assert (archive.write_header (entry) == Archive.Result.OK);
        assert (archive.finish_entry () == Archive.Result.OK);
    }

    private void add_archive_symlink (Archive.Write archive, string path, string target) {
        var entry = new Archive.Entry (archive);
        entry.set_pathname (path);
        entry.set_filetype (Archive.FileType.IFLNK);
        entry.set_perm ((Archive.FileMode) 0777);
        entry.set_size (0);
        entry.set_symlink (target);
        assert (archive.write_header (entry) == Archive.Result.OK);
        assert (archive.finish_entry () == Archive.Result.OK);
    }

    private void add_archive_file (Archive.Write archive, string path, string content) {
        var entry = new Archive.Entry (archive);
        entry.set_pathname (path);
        entry.set_filetype (Archive.FileType.IFREG);
        entry.set_perm ((Archive.FileMode) 0644);
        entry.set_size (content.data.length);
        assert (archive.write_header (entry) == Archive.Result.OK);
        assert (archive.write_data (content.data) == content.data.length);
        assert (archive.finish_entry () == Archive.Result.OK);
    }

    private void create_archive (string path, bool include_symlink_traversal = false) {
        var archive = new Archive.Write ();
        assert (archive.set_format_pax_restricted () == Archive.Result.OK);
        assert (archive.open_filename (path) == Archive.Result.OK);
        add_archive_directory (archive, "runner/");
        if (include_symlink_traversal) {
            add_archive_symlink (archive, "runner/escape", "../../../../outside");
            add_archive_file (archive, "runner/escape/written-outside.txt", "unsafe");
        } else {
            add_archive_file (archive, "runner/content.txt", "safe");
        }
        assert (archive.close () == Archive.Result.OK);
    }

    private string read_link (string path) {
        try {
            return FileUtils.read_link (path);
        } catch (FileError e) {
            critical ("Could not read symlink %s: %s", path, e.message);
            assert_not_reached ();
        }
    }

    private void test_delete_nested_directory () {
        var root = create_temp_directory ();
        var nested = Path.build_filename (root, "first", "second");
        assert (ProtonPlus.Utils.Filesystem.create_directory (nested));

        var file_path = Path.build_filename (nested, "content.txt");
        ProtonPlus.Utils.Filesystem.create_file (file_path, "test content");
        assert (FileUtils.test (file_path, FileTest.IS_REGULAR));

        assert (delete_directory (root));
        assert (!FileUtils.test (root, FileTest.EXISTS));
    }

    private void test_delete_root_symlink_preserves_target () {
        var root = create_temp_directory ();
        var target = Path.build_filename (root, "target");
        var link = Path.build_filename (root, "linked-directory");
        var protected_file = Path.build_filename (target, "keep.txt");
        assert (ProtonPlus.Utils.Filesystem.create_directory (target));
        ProtonPlus.Utils.Filesystem.create_file (protected_file, "keep");
        assert (Posix.symlink (target, link) == 0);

        assert (delete_directory (link));
        assert (!FileUtils.test (link, FileTest.IS_SYMLINK));
        assert (FileUtils.test (protected_file, FileTest.IS_REGULAR));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (protected_file) == "keep");

        assert (delete_directory (root));
    }

    private void test_clear_cache_root_symlink_preserves_target () {
        var root = create_temp_directory ();
        var target = Path.build_filename (root, "target");
        var cache_link = Path.build_filename (root, "cache");
        var protected_file = Path.build_filename (target, "keep.txt");
        var previous_cache_path = ProtonPlus.Globals.CACHE_PATH;
        assert (ProtonPlus.Utils.Filesystem.create_directory (target));
        ProtonPlus.Utils.Filesystem.create_file (protected_file, "keep");
        assert (Posix.symlink (target, cache_link) == 0);
        ProtonPlus.Globals.CACHE_PATH = cache_link;

        assert (clear_cache ());
        assert (FileUtils.test (protected_file, FileTest.IS_REGULAR));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (protected_file) == "keep");
        assert (FileUtils.test (cache_link, FileTest.IS_DIR));
        assert (!FileUtils.test (cache_link, FileTest.IS_SYMLINK));

        ProtonPlus.Globals.CACHE_PATH = previous_cache_path;
        assert (delete_directory (root));
    }

    private void test_copy_preserves_symlinks () {
        var root = create_temp_directory ();
        var source = Path.build_filename (root, "source");
        var destination = Path.build_filename (root, "destination");
        var drive_c = Path.build_filename (source, "drive_c");
        var dosdevices = Path.build_filename (source, "dosdevices");
        var absolute_target = Path.build_filename (root, "absolute-target");
        assert (ProtonPlus.Utils.Filesystem.create_directory (drive_c));
        assert (ProtonPlus.Utils.Filesystem.create_directory (dosdevices));
        assert (ProtonPlus.Utils.Filesystem.create_directory (absolute_target));

        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (drive_c, "relative.txt"), "relative");
        ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (absolute_target, "absolute.txt"), "absolute");

        var absolute_link = Path.build_filename (dosdevices, "z:");
        var relative_link = Path.build_filename (dosdevices, "c:");
        var broken_link = Path.build_filename (dosdevices, "broken:");
        assert (Posix.symlink (absolute_target, absolute_link) == 0);
        assert (Posix.symlink ("../drive_c", relative_link) == 0);
        assert (Posix.symlink ("missing-target", broken_link) == 0);

        assert (copy_directory (source, destination));

        var copied_dosdevices = Path.build_filename (destination, "dosdevices");
        var copied_absolute_link = Path.build_filename (copied_dosdevices, "z:");
        var copied_relative_link = Path.build_filename (copied_dosdevices, "c:");
        var copied_broken_link = Path.build_filename (copied_dosdevices, "broken:");
        assert (FileUtils.test (copied_absolute_link, FileTest.IS_SYMLINK));
        assert (read_link (copied_absolute_link) == absolute_target);
        assert (FileUtils.test (copied_relative_link, FileTest.IS_SYMLINK));
        assert (read_link (copied_relative_link) == "../drive_c");
        assert (FileUtils.test (copied_broken_link, FileTest.IS_SYMLINK));
        assert (read_link (copied_broken_link) == "missing-target");
        assert (delete_directory (root));
    }

    private void test_move_conflict_completes () {
        var root = create_temp_directory ();
        var source = Path.build_filename (root, "source");
        var target = Path.build_filename (root, "target");
        assert (ProtonPlus.Utils.Filesystem.create_directory (source));
        assert (ProtonPlus.Utils.Filesystem.create_directory (target));

        var source_file = Path.build_filename (source, "existing.txt");
        var target_file = Path.build_filename (target, "existing.txt");
        ProtonPlus.Utils.Filesystem.create_file (source_file, "source");
        ProtonPlus.Utils.Filesystem.create_file (target_file, "target");

        var loop = new MainLoop ();
        bool callback_completed = false;
        bool move_succeeded = true;
        var timeout_id = Timeout.add_seconds (5, () => {
            loop.quit ();
            return Source.REMOVE;
        });

        ProtonPlus.Utils.Filesystem.move_dir_contents.begin (source, target, (obj, result) => {
            assert (obj == null);
            move_succeeded = ProtonPlus.Utils.Filesystem.move_dir_contents.end (result);
            callback_completed = true;
            Source.remove (timeout_id);
            loop.quit ();
        });
        loop.run ();

        assert (callback_completed);
        assert (!move_succeeded);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (source_file) == "source");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (target_file) == "target");
        assert (delete_directory (root));
    }

    private void test_extract_through_symlinked_ancestor () {
        var root = create_temp_directory ();
        var resolved_home = Path.build_filename (root, "var", "home");
        var linked_home = Path.build_filename (root, "home");
        var workspace = Path.build_filename (linked_home, "workspace");
        assert (ProtonPlus.Utils.Filesystem.create_directory (resolved_home));
        assert (Posix.symlink (Path.build_filename ("var", "home"), linked_home) == 0);
        assert (ProtonPlus.Utils.Filesystem.create_directory (workspace));
        create_archive (Path.build_filename (workspace, "archive.tar"));

        var extracted = extract (workspace, "archive", ".tar");
        var caller_visible_path = Path.build_filename (workspace, "runner");
        assert (extracted == caller_visible_path);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename (caller_visible_path, "content.txt")
        ) == "safe");
        assert (FileUtils.test (
            Path.build_filename (resolved_home, "workspace", "runner", "content.txt"),
            FileTest.IS_REGULAR
        ));

        assert (delete_directory (root));
    }

    private void test_extract_rejects_archive_symlink_traversal () {
        var root = create_temp_directory ();
        var resolved_home = Path.build_filename (root, "var", "home");
        var linked_home = Path.build_filename (root, "home");
        var workspace = Path.build_filename (linked_home, "workspace");
        var outside = Path.build_filename (root, "outside");
        var outside_sentinel = Path.build_filename (outside, "keep.txt");
        var outside_write = Path.build_filename (outside, "written-outside.txt");
        assert (ProtonPlus.Utils.Filesystem.create_directory (resolved_home));
        assert (Posix.symlink (Path.build_filename ("var", "home"), linked_home) == 0);
        assert (ProtonPlus.Utils.Filesystem.create_directory (workspace));
        assert (ProtonPlus.Utils.Filesystem.create_directory (outside));
        ProtonPlus.Utils.Filesystem.create_file (outside_sentinel, "keep");
        create_archive (Path.build_filename (workspace, "archive.tar"), true);

        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Cannot extract through symlink*");
        var extracted = extract (workspace, "archive", ".tar");
        Test.assert_expected_messages ();
        assert (extracted == "");
        assert (!FileUtils.test (outside_write, FileTest.EXISTS));
        assert (ProtonPlus.Utils.Filesystem.get_file_content (outside_sentinel) == "keep");

        assert (delete_directory (root));
    }

    private void test_extract_canonicalization_failure_is_clean () {
        var root = create_temp_directory ();
        var missing_workspace = Path.build_filename (root, "missing-workspace");

        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Could not resolve extraction directory*");
        assert (extract (missing_workspace, "archive", ".tar") == "");
        Test.assert_expected_messages ();
        assert (!FileUtils.test (missing_workspace, FileTest.EXISTS));

        assert (delete_directory (root));
    }
}
