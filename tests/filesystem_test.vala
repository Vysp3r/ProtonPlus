namespace AppTests.FilesystemTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/filesystem/delete-nested-directory", test_delete_nested_directory);
        Test.add_func ("/filesystem/delete-root-symlink-preserves-target", test_delete_root_symlink_preserves_target);
        Test.add_func ("/filesystem/clear-cache-root-symlink-preserves-target", test_clear_cache_root_symlink_preserves_target);
        Test.add_func ("/filesystem/copy-preserves-symlinks", test_copy_preserves_symlinks);
        Test.add_func ("/filesystem/move-conflict-completes", test_move_conflict_completes);
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
}
