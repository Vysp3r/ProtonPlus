namespace ScriptTests.CheckCommand {
    const string COMMAND_LOG = "commands";

    string build_directory (Fixture fixture) {
        return fixture.path ("custom build");
    }

    void setup (Fixture fixture) throws Error {
        fixture.copy ("tests/check.sh");
        make_directory (fixture.path ("tests"));
        fixture.launcher.setenv ("BUILD_DIR", "custom build", true);
        fixture.launcher.setenv ("PROTONPLUS_CHECK_LOG", fixture.path (COMMAND_LOG), true);
        fixture.launcher.unsetenv ("PROTONPLUS_FAIL_COMMAND");
        fixture.launcher.unsetenv ("PROTONPLUS_EMPTY_TEST_PATH");

        fixture.executable (Path.build_filename (fixture.bin, "meson"), """#!/bin/bash
set -eu
{ printf 'meson\t%s' "$PWD"; printf '\t%s' "$@"; printf '\n'; } >> "$PROTONPLUS_CHECK_LOG"
if [[ $1 == setup ]]; then
    mkdir -p "$2/meson-private"
    touch "$2/meson-private/coredata.dat"
fi
if [[ ${PROTONPLUS_FAIL_COMMAND:-} == "$1" ]]; then
    exit 23
fi
""");
        fixture.executable (Path.build_filename (fixture.bin, "git"), """#!/bin/bash
set -eu
{ printf 'git\t%s' "$PWD"; printf '\t%s' "$@"; printf '\n'; } >> "$PROTONPLUS_CHECK_LOG"
if [[ ${PROTONPLUS_FAIL_COMMAND:-} == git ]]; then
    exit 24
fi
""");
        fixture.executable (build_directory (fixture) + "/tests/protonplus-tests", """#!/bin/bash
set -eu
command=unit-tests
if [[ ${2:-} == -l ]]; then
    command=unit-list
fi
{ printf '%s\t%s' "$command" "$PWD"; printf '\t%s' "$@"; printf '\n'; } >> "$PROTONPLUS_CHECK_LOG"
if [[ ${PROTONPLUS_FAIL_COMMAND:-} == "$command" ]]; then
    if [[ $command == unit-list ]]; then exit 26; fi
    exit 25
fi
if [[ $command == unit-list ]]; then
    printf '%s\n' 'TAP version 14'
    if [[ ${PROTONPLUS_EMPTY_TEST_PATH:-} == "${!#}" ]]; then
        printf '%s\n' '1..0'
    else
        printf '%s\n' '1..1'
    fi
fi
""");
    }

    string[] commands (Fixture fixture) throws Error {
        var path = fixture.path (COMMAND_LOG);
        return FileUtils.test (path, FileTest.EXISTS) ? read_text (path).strip ().split ("\n") : new string[0];
    }

    string record (string command, string directory, string[] arguments) {
        return "%s\t%s\t%s".printf (command, directory, string.joinv ("\t", arguments));
    }

    string[] unit_commands (Fixture fixture) throws Error {
        string[] selected = {};
        foreach (var command in commands (fixture)) {
            if (command.has_prefix ("unit-"))
                selected += command;
        }
        return selected;
    }

    string command_action (string command) {
        string[] fields = command.split ("\t");
        return fields[0] == "meson" ? fields[2] : fields[0];
    }

    void full_check (Fixture fixture) throws Error {
        setup (fixture);
        var build = build_directory (fixture);
        fixture.bash ("tests/check.sh").expect_status (0);
        string[] expected = {
            record ("meson", fixture.checkout, { "setup", build }),
            record ("meson", fixture.checkout, { "compile", "-C", build }),
            record ("meson", fixture.checkout, { "test", "-C", build, "--no-rebuild", "--print-errorlogs" }),
            record ("git", fixture.checkout, { "diff", "--check" }),
        };
        expect_lines (commands (fixture), expected);
        File.new_for_path (fixture.path (COMMAND_LOG)).delete ();
        fixture.bash ("tests/check.sh").expect_status (0);
        expect_lines (commands (fixture), expected[1:expected.length]);
    }

    void focused_paths (Fixture fixture) throws Error {
        setup (fixture);
        var test_directory = fixture.path ("tests");
        fixture.bash ("tests/check.sh", { "/web", "/web/persistent" }).expect_status (0);
        expect_lines (unit_commands (fixture), {
            record ("unit-list", test_directory, { "--tap", "-l", "-p", "/web" }),
            record ("unit-tests", test_directory, { "-p", "/web" }),
            record ("unit-list", test_directory, { "--tap", "-l", "-p", "/web/persistent" }),
            record ("unit-tests", test_directory, { "-p", "/web/persistent" }),
        });
        foreach (var command in commands (fixture))
            require (command_action (command) != "test", "Unexpected Meson test: " + command);
    }

    void named_area (Fixture fixture) throws Error {
        setup (fixture);
        var test_directory = fixture.path ("tests");
        fixture.bash ("tests/check.sh", { "downloads" }).expect_status (0);
        expect_lines (unit_commands (fixture), {
            record ("unit-list", test_directory, { "--tap", "-l", "-r", "/web" }),
            record ("unit-tests", test_directory, { "-r", "/web" }),
        });
    }

    void shared_native_build (Fixture fixture) throws Error {
        setup (fixture);
        fixture.copy ("Makefile");
        write_text (fixture.path ("data/com.vysp3r.ProtonPlus.gschema.xml"), "<schemalist/>");
        foreach (var command in new string[] { "ninja", "glib-compile-schemas" })
            fixture.executable (Path.build_filename (fixture.bin, command), "#!/bin/sh\nexit 0\n");
        fixture.launcher.unsetenv ("BUILD_DIR");
        var build = fixture.path ("build");
        fixture.run ({ "make", "-C", fixture.checkout, "native" }).expect_status (0);
        fixture.bash ("tests/check.sh").expect_status (0);

        string[] build_commands = {};
        foreach (var command in commands (fixture)) {
            if (command_action (command) in new string[] { "setup", "compile" })
                build_commands += command;
        }
        expect_lines (build_commands, {
            record ("meson", fixture.checkout, { "setup", build, "--prefix=/usr" }),
            record ("meson", fixture.checkout, { "compile", "-C", build }),
            record ("meson", fixture.checkout, { "compile", "-C", build }),
        });
    }

    void propagates_failures (Fixture fixture) throws Error {
        setup (fixture);
        string[] failures = { "setup", "compile", "test", "unit-list", "unit-tests", "git" };
        int[] statuses = { 23, 23, 23, 26, 25, 24 };
        for (var index = 0; index < failures.length; index++) {
            var failure = failures[index];
            write_text (fixture.path (COMMAND_LOG), "");
            fixture.launcher.setenv ("PROTONPLUS_FAIL_COMMAND", failure, true);
            var result = failure.has_prefix ("unit-")
                ? fixture.bash ("tests/check.sh", { "/cli", "/providers" })
                : fixture.bash ("tests/check.sh");
            result.expect_status (statuses[index]);
            var log = commands (fixture);
            require (log.length > 0, "Fixture did not execute " + failure);
            expect_text (command_action (log[log.length - 1]), failure);
        }
    }

    void empty_selection (Fixture fixture) throws Error {
        setup (fixture);
        fixture.launcher.setenv ("PROTONPLUS_EMPTY_TEST_PATH", "/missing", true);
        var result = fixture.bash ("tests/check.sh", { "/missing" });
        result.expect_status (1);
        require (result.errors.contains ("No GLib tests match: /missing"), result.errors);
        foreach (var command in commands (fixture)) {
            require (!(command_action (command) in new string[] { "unit-tests", "git" }),
                "Unexpected command after empty test selection: " + command);
        }
    }

    void invalid_selection (Fixture fixture) throws Error {
        setup (fixture);
        var result = fixture.bash ("tests/check.sh", { "unknown-area" });
        result.expect_status (1);
        require (result.errors.contains ("starting with /"), result.errors);
        require (commands (fixture).length == 0, "Invalid selection launched a build");
    }

    int main (string[] args) {
        Test.init (ref args);
        register ("/check-command/full-check", full_check);
        register ("/check-command/focused-paths", focused_paths);
        register ("/check-command/named-area", named_area);
        register ("/check-command/shared-native-build", shared_native_build);
        register ("/check-command/propagates-failures", propagates_failures);
        register ("/check-command/empty-selection", empty_selection);
        register ("/check-command/invalid-selection", invalid_selection);
        return Test.run ();
    }
}
