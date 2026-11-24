namespace ScriptTests {
    errordomain CheckFailure {
        MISMATCH
    }

    void require (bool condition, string message) throws Error {
        if (!condition)
            throw new CheckFailure.MISMATCH (message);
    }

    void expect_text (string actual, string expected) throws Error {
        require (actual == expected, "Expected:\n%s\nActual:\n%s".printf (expected, actual));
    }

    void expect_lines (string[] actual, string[] expected) throws Error {
        expect_text (string.joinv ("\n", actual), string.joinv ("\n", expected));
    }

    string read_text (string path) throws Error {
        string text;
        FileUtils.get_contents (path, out text);
        return text;
    }

    void make_directory (string path) throws Error {
        require (DirUtils.create_with_parents (path, 0700) == 0,
            "Cannot create fixture directory " + path);
    }

    void write_text (string path, string text) throws Error {
        make_directory (Path.get_dirname (path));
        FileUtils.set_contents (path, text);
    }

    class CommandResult : Object {
        public string command;
        public int status;
        public string output;
        public string errors;

        public void expect_status (int expected) throws Error {
            require (status == expected, "%s exited %d (expected %d)\n%s%s".printf (
                command, status, expected, output, errors));
        }
    }

    class Fixture : Object {
        public string root { get; private set; }
        public string checkout { get; private set; }
        public string bin { get; private set; }
        public SubprocessLauncher launcher { get; private set; }

        public Fixture () throws Error {
            root = DirUtils.make_tmp ("protonplus-script-test-XXXXXX");
            checkout = Path.build_filename (root, "checkout with spaces");
            bin = Path.build_filename (root, "bin");
            launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            launcher.setenv ("PATH", bin + ":" + Environment.get_variable ("PATH"), true);
        }

        public string path (string relative) {
            return Path.build_filename (checkout, relative);
        }

        public void copy (string relative) throws Error {
            var destination = path (relative);
            make_directory (Path.get_dirname (destination));
            File.new_for_path (relative).copy (File.new_for_path (destination), FileCopyFlags.NONE);
        }

        public void executable (string path, string text) throws Error {
            write_text (path, text);
            File.new_for_path (path).set_attribute_uint32 (
                FileAttribute.UNIX_MODE, 0755, FileQueryInfoFlags.NONE);
        }

        public CommandResult run (string[] arguments, string? directory = null) throws Error {
            launcher.set_cwd (directory ?? root);
            var process = launcher.spawnv (arguments);
            string? output;
            string? errors;
            process.communicate_utf8 (null, null, out output, out errors);
            var result = new CommandResult ();
            result.command = string.joinv (" ", arguments);
            result.status = process.get_if_exited () ? process.get_exit_status () : 128 + process.get_term_sig ();
            result.output = output ?? "";
            result.errors = errors ?? "";
            return result;
        }

        public CommandResult bash (string script, string[] arguments = {}) throws Error {
            string[] command = { "bash", path (script) };
            foreach (var argument in arguments)
                command += argument;
            return run (command);
        }

        public void clean_up () throws Error {
            remove_tree (File.new_for_path (root));
        }

        static void remove_tree (File file) throws Error {
            if (file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS) == FileType.DIRECTORY) {
                var entries = file.enumerate_children (FileAttribute.STANDARD_NAME,
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                FileInfo? info;
                while ((info = entries.next_file ()) != null)
                    remove_tree (file.get_child (info.get_name ()));
            }
            file.delete ();
        }
    }

    delegate void Scenario (Fixture fixture) throws Error;

    void register (string path, owned Scenario scenario) {
        Test.add_data_func (path, () => {
            Fixture? fixture = null;
            try {
                fixture = new Fixture ();
                scenario (fixture);
            } catch (Error error) {
                Test.message ("%s", error.message);
                Test.fail ();
            }
            if (fixture != null) {
                try {
                    fixture.clean_up ();
                } catch (Error error) {
                    Test.message ("%s", error.message);
                    Test.fail ();
                }
            }
        });
    }
}
