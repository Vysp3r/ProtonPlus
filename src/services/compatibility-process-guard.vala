namespace ProtonPlus.Services {
    public enum CompatibilityProcessInspectionStatus {
        CLEAR,
        ACTIVE,
        UNKNOWN
    }

    public enum CompatibilityProcessOperationKind {
        INSTALL,
        UPDATE,
        REPLACEMENT,
        REMOVAL
    }

    public enum CompatibilityProcessMatchReason {
        NONE,
        EXECUTABLE_IN_TARGET,
        ARGUMENT_PATH_IN_TARGET
    }

    public class CompatibilityProcessOperationContext : Object {
        public CompatibilityProcessOperationKind operation_kind { get; private set; }
        public string installation_path { get; private set; }
        public string launcher_family_id { get; private set; }
        public string launcher_instance_id { get; private set; }
        public string tool_target_family_id { get; private set; }
        public string tool_target_id { get; private set; }
        public bool mutates_existing_destination { get; private set; }

        public CompatibilityProcessOperationContext (
            CompatibilityProcessOperationKind operation_kind,
            string installation_path,
            string launcher_family_id,
            string launcher_instance_id,
            string tool_target_family_id,
            string tool_target_id,
            bool mutates_existing_destination
        ) {
            this.operation_kind = operation_kind;
            this.installation_path = normalize_path (installation_path);
            this.launcher_family_id = launcher_family_id;
            this.launcher_instance_id = launcher_instance_id;
            this.tool_target_family_id = tool_target_family_id;
            this.tool_target_id = tool_target_id;
            this.mutates_existing_destination = mutates_existing_destination;
        }

        private static string normalize_path (string path) {
            var canonical = Filename.canonicalize (path, null);
            var resolved = Posix.realpath (canonical);
            return resolved ?? canonical;
        }
    }

    /* Process records deliberately separate the executable from argv so the
     * guard can make token-based decisions without scraping formatted `ps`
     * text. */
    public class CompatibilityProcessRecord : Object {
        public int pid { get; private set; }
        public string executable_path { get; private set; }
        public Gee.List<string> argv { get; private set; }
        public bool executable_available { get; private set; default = true; }
        public bool argv_available { get; private set; default = true; }
        public string? inspection_error { get; private set; default = null; }

        public CompatibilityProcessRecord (
            int pid,
            string executable_path,
            Gee.List<string>? argv = null
        ) {
            this.pid = pid;
            this.executable_path = executable_path;
            this.argv = argv ?? new Gee.ArrayList<string> ();
        }

        /* procfs exposes argv as raw NUL-separated bytes.  Empty arguments
         * between delimiters are significant; a final delimiter terminates
         * the last argument and does not create an extra one. */
        public CompatibilityProcessRecord.from_cmdline_bytes (
            int pid,
            string executable_path,
            uint8[] command_line
        ) {
            this (pid, executable_path, decode_cmdline (command_line));
        }

        public CompatibilityProcessRecord.with_unreadable_executable (
            int pid,
            uint8[] command_line,
            string inspection_error
        ) {
            this (pid, "", decode_cmdline (command_line));
            executable_available = false;
            this.inspection_error = inspection_error;
        }

        public CompatibilityProcessRecord.with_unreadable_argv (
            int pid,
            string executable_path,
            string inspection_error
        ) {
            this (pid, executable_path);
            argv_available = false;
            this.inspection_error = inspection_error;
        }

        public CompatibilityProcessRecord.with_unreadable_metadata (
            int pid,
            string inspection_error
        ) {
            this (pid, "");
            executable_available = false;
            argv_available = false;
            this.inspection_error = inspection_error;
        }

        public bool has_complete_metadata () {
            return executable_available && argv_available;
        }

        public static Gee.List<string> decode_cmdline (uint8[] command_line) {
            var result = new Gee.ArrayList<string> ();
            var start = 0;
            for (var index = 0; index < command_line.length; index++) {
                if (command_line[index] != 0)
                    continue;
                result.add (decode_argument (command_line, start, index));
                start = index + 1;
            }
            if (start < command_line.length)
                result.add (decode_argument (command_line, start, command_line.length));
            return result;
        }

        internal static bool cmdline_is_valid (uint8[] command_line) {
            var start = 0;
            for (var index = 0; index < command_line.length; index++) {
                if (command_line[index] != 0)
                    continue;
                if (!decode_argument (command_line, start, index).validate ())
                    return false;
                start = index + 1;
            }
            return start >= command_line.length ||
                decode_argument (command_line, start, command_line.length).validate ();
        }

        private static string decode_argument (uint8[] bytes, int start, int end) {
            var value = new StringBuilder ();
            for (var index = start; index < end; index++)
                value.append_c ((char) bytes[index]);
            return value.str;
        }
    }

    public class CompatibilityProcessInspectionResult : Object {
        public CompatibilityProcessInspectionStatus status { get; private set; }
        public CompatibilityProcessRecord? blocker { get; private set; }
        public CompatibilityProcessMatchReason blocker_reason { get; private set; }
        public string? inspection_error { get; private set; }
        internal Gee.List<CompatibilityProcessRecord> processes { get; private set; }

        private CompatibilityProcessInspectionResult (
            CompatibilityProcessInspectionStatus status,
            CompatibilityProcessRecord? blocker = null,
            CompatibilityProcessMatchReason blocker_reason = CompatibilityProcessMatchReason.NONE,
            string? inspection_error = null,
            Gee.List<CompatibilityProcessRecord>? processes = null
        ) {
            this.status = status;
            this.blocker = blocker;
            this.blocker_reason = blocker_reason;
            this.inspection_error = inspection_error;
            this.processes = processes ?? new Gee.ArrayList<CompatibilityProcessRecord> ();
        }

        public static CompatibilityProcessInspectionResult clear (
            Gee.List<CompatibilityProcessRecord>? processes = null
        ) {
            return new CompatibilityProcessInspectionResult (
                CompatibilityProcessInspectionStatus.CLEAR,
                null,
                CompatibilityProcessMatchReason.NONE,
                null,
                processes
            );
        }

        public static CompatibilityProcessInspectionResult active (
            CompatibilityProcessRecord blocker,
            CompatibilityProcessMatchReason blocker_reason
        ) {
            return new CompatibilityProcessInspectionResult (
                CompatibilityProcessInspectionStatus.ACTIVE, blocker, blocker_reason
            );
        }

        public static CompatibilityProcessInspectionResult unknown (string error) {
            return new CompatibilityProcessInspectionResult (
                CompatibilityProcessInspectionStatus.UNKNOWN,
                null,
                CompatibilityProcessMatchReason.NONE,
                error
            );
        }
    }

    public interface CompatibilityProcessQueryBackend : Object {
        public abstract async CompatibilityProcessInspectionResult inspect_processes ();
    }

    /* The native procfs walk is intentionally moved to a worker thread so a
     * GUI action cannot block GTK while process state is inspected. */
    public class NativeCompatibilityProcessQueryBackend : Object, CompatibilityProcessQueryBackend {
        private string proc_root;

        public NativeCompatibilityProcessQueryBackend (string proc_root = "/proc") {
            this.proc_root = proc_root;
        }

        public async CompatibilityProcessInspectionResult inspect_processes () {
            SourceFunc callback = inspect_processes.callback;
            CompatibilityProcessInspectionResult result =
                CompatibilityProcessInspectionResult.unknown ("Process inspection did not complete.");

            new Thread<void> ("compatibility-process-query", () => {
                result = inspect_processes_sync ();
                Idle.add ((owned) callback, Priority.DEFAULT);
            });

            yield;
            return result;
        }

        private CompatibilityProcessInspectionResult inspect_processes_sync () {
            try {
                var records = new Gee.ArrayList<CompatibilityProcessRecord> ();
                var directory = File.new_for_path (proc_root).enumerate_children (
                    "standard::name,unix::uid", FileQueryInfoFlags.NONE, null
                );
                var current_user_id = (uint32) Posix.geteuid ();
                FileInfo? info;
                while ((info = directory.next_file (null)) != null) {
                    var name = info.get_name ();
                    int pid;
                    if (!int.try_parse (name, out pid) || pid <= 0)
                        continue;
                    if (!info.has_attribute (FileAttribute.UNIX_UID)) {
                        return CompatibilityProcessInspectionResult.unknown (
                            "Unable to determine the owner of process %d.".printf (pid)
                        );
                    }
                    if (info.get_attribute_uint32 (FileAttribute.UNIX_UID) != current_user_id)
                        continue;

                    var root = Path.build_filename (proc_root, name);
                    uint8[] command_line = {};
                    var command_line_available = true;
                    string? command_line_error = null;
                    try {
                        FileUtils.get_data (Path.build_filename (root, "cmdline"), out command_line);
                    } catch (FileError e) {
                        if (process_has_disappeared (root))
                            continue;
                        command_line_available = false;
                        command_line_error = process_read_failure_message (pid, "command line", e);
                    }

                    /* Kernel threads and zombies expose an empty cmdline and
                     * have no meaningful user-space executable to associate
                     * with a compatibility-tool installation. */
                    if (command_line_available && command_line.length == 0)
                        continue;
                    if (command_line_available &&
                        !CompatibilityProcessRecord.cmdline_is_valid (command_line)) {
                        command_line_available = false;
                        command_line_error =
                            "Process %d returned malformed command-line data.".printf (pid);
                    }

                    var executable = "";
                    var executable_available = true;
                    string? executable_error = null;
                    try {
                        executable = FileUtils.read_link (Path.build_filename (root, "exe"));
                    } catch (FileError e) {
                        if (process_has_disappeared (root))
                            continue;

                        /* A process may become a zombie after its non-empty
                         * cmdline was read but before exe.  Rechecking avoids
                         * turning that ordinary transition into UNKNOWN. */
                        if (command_line_available) {
                            uint8[] retry_command_line;
                            try {
                                FileUtils.get_data (
                                    Path.build_filename (root, "cmdline"), out retry_command_line
                                );
                            } catch (FileError retry_error) {
                                if (process_has_disappeared (root))
                                    continue;
                                command_line_available = false;
                                command_line_error = process_read_failure_message (
                                    pid, "command line", retry_error
                                );
                            }
                            if (command_line_available) {
                                if (retry_command_line.length == 0)
                                    continue;
                                if (CompatibilityProcessRecord.cmdline_is_valid (retry_command_line))
                                    command_line = retry_command_line;
                                else {
                                    command_line_available = false;
                                    command_line_error =
                                        "Process %d returned malformed command-line data.".printf (pid);
                                }
                            }
                        }
                        executable_available = false;
                        executable_error = process_read_failure_message (pid, "executable", e);
                    }
                    if (executable_available && !executable.validate ()) {
                        executable_available = false;
                        executable_error =
                            "Process %d returned malformed executable data.".printf (pid);
                    }
                    if (executable_available && command_line_available) {
                        records.add (new CompatibilityProcessRecord.from_cmdline_bytes (
                            pid, executable, command_line
                        ));
                    } else if (command_line_available) {
                        records.add (new CompatibilityProcessRecord.with_unreadable_executable (
                            pid, command_line, (!) executable_error
                        ));
                    } else if (executable_available) {
                        records.add (new CompatibilityProcessRecord.with_unreadable_argv (
                            pid, executable, (!) command_line_error
                        ));
                    } else {
                        records.add (new CompatibilityProcessRecord.with_unreadable_metadata (
                            pid, "%s %s".printf (
                                (!) executable_error, (!) command_line_error
                            )
                        ));
                    }
                }
                directory.close (null);
                return CompatibilityProcessInspectionResult.clear (records);
            } catch (Error e) {
                return CompatibilityProcessInspectionResult.unknown (
                    "Unable to inspect %s: %s".printf (proc_root, e.message)
                );
            }
        }

        private static bool process_has_disappeared (string process_root) {
            try {
                var info = File.new_for_path (process_root).query_info (
                    FileAttribute.STANDARD_TYPE,
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                    null
                );
                return info.get_file_type () != FileType.DIRECTORY;
            } catch (IOError e) {
                return e.code == IOError.NOT_FOUND || e.code == IOError.NOT_DIRECTORY;
            } catch (Error e) {
                /* Permission and other persistent failures are not evidence
                 * that the enumerated same-user process disappeared. */
                return false;
            }
        }

        private static string process_read_failure_message (
            int pid,
            string field,
            FileError error
        ) {
            return "Unable to inspect the %s of same-user process %d: %s".printf (
                field, pid, error.message
            );
        }
    }

    public interface FlatpakHostProcessQuery : Object {
        public abstract async Utils.CommandResult run ();
    }

    private class HostFlatpakProcessQuery : Object, FlatpakHostProcessQuery {
        /* Each host record is PID, base64(executable), base64(raw cmdline).
         * A dash marks a per-process field that could not be read.  Encoding
         * keeps NUL-separated argv intact across the subprocess boundary and
         * avoids reconstructing arguments from `ps` output.  A final status
         * record proves that the entire same-user scan completed. */
        private const string QUERY_SCRIPT =
            "current_uid=$(id -u) || exit 70; " +
            "scan_failed=false; " +
            "for process_dir in /proc/[0-9]*; do " +
                "if [ \"$process_dir\" = '/proc/[0-9]*' ]; then exit 70; fi; " +
                "owner=$(stat -c '%u' \"$process_dir\" 2>/dev/null); owner_status=$?; " +
                "if [ \"$owner_status\" -ne 0 ]; then " +
                    "if [ -d \"$process_dir\" ]; then scan_failed=true; fi; continue; " +
                "fi; " +
                "if [ \"$owner\" != \"$current_uid\" ]; then continue; fi; " +
                "command_line=$(base64 -w 0 \"$process_dir/cmdline\" 2>/dev/null); command_status=$?; " +
                "if [ \"$command_status\" -eq 0 ] && [ -z \"$command_line\" ]; then continue; fi; " +
                "executable=$(readlink \"$process_dir/exe\" 2>/dev/null); executable_status=$?; " +
                "if [ \"$executable_status\" -ne 0 ]; then " +
                    "if [ ! -d \"$process_dir\" ]; then continue; fi; " +
                    "if [ \"$command_status\" -eq 0 ]; then " +
                        "retry_command_line=$(base64 -w 0 \"$process_dir/cmdline\" 2>/dev/null); retry_status=$?; " +
                        "if [ \"$retry_status\" -ne 0 ]; then command_status=$retry_status; command_line='-'; " +
                        "elif [ -z \"$retry_command_line\" ]; then continue; " +
                        "else command_line=$retry_command_line; fi; " +
                    "fi; " +
                    "encoded_executable='-'; " +
                "else " +
                    "encoded_executable=$(printf '%s' \"$executable\" | base64 -w 0); encode_status=$?; " +
                    "if [ \"$encode_status\" -ne 0 ]; then encoded_executable='-'; fi; " +
                "fi; " +
                "if [ \"$command_status\" -ne 0 ]; then command_line='-'; fi; " +
                "printf 'R\\t%s\\t%s\\t%s\\n' \"${process_dir##*/}\" \"$encoded_executable\" \"$command_line\" || exit 70; " +
            "done; " +
            "if $scan_failed; then printf 'S\\tFAILED\\n'; exit 71; fi; " +
            "printf 'S\\tOK\\n'";

        public async Utils.CommandResult run () {
            try {
                string[] argv = {
                    "flatpak-spawn", "--host", "/bin/sh", "-c", QUERY_SCRIPT
                };
                var subprocess = new Subprocess.newv (
                    argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
                );
                Bytes stdout_bytes;
                Bytes stderr_bytes;
                yield subprocess.communicate_async (
                    null, null, out stdout_bytes, out stderr_bytes
                );
                var stdout = stdout_bytes != null
                    ? Utils.Parser.data_to_string (stdout_bytes.get_data ()) : "";
                var stderr = stderr_bytes != null
                    ? Utils.Parser.data_to_string (stderr_bytes.get_data ()) : "";
                var exit_status = subprocess.get_if_exited ()
                    ? subprocess.get_exit_status () : -1;
                return new Utils.CommandResult (stdout, stderr, exit_status);
            } catch (Error e) {
                return new Utils.CommandResult ("", e.message, -1);
            }
        }
    }

    public class FlatpakCompatibilityProcessQueryBackend : Object, CompatibilityProcessQueryBackend {
        private FlatpakHostProcessQuery host_query;

        public FlatpakCompatibilityProcessQueryBackend (
            FlatpakHostProcessQuery? host_query = null
        ) {
            this.host_query = host_query ?? new HostFlatpakProcessQuery ();
        }

        public async CompatibilityProcessInspectionResult inspect_processes () {
            var command = yield host_query.run ();
            if (command.exit_status != 0) {
                var detail = command.stderr.strip ();
                if (detail == "")
                    detail = command.stdout.strip ();
                if (detail == "")
                    detail = "no diagnostic output";
                if (command.exit_status < 0) {
                    return CompatibilityProcessInspectionResult.unknown (
                        "Unable to launch the Flatpak host process query: %s".printf (detail)
                    );
                }
                return CompatibilityProcessInspectionResult.unknown (
                    "Flatpak host process query exited with status %d: %s".printf (
                        command.exit_status, detail
                    )
                );
            }

            var records = new Gee.ArrayList<CompatibilityProcessRecord> ();
            var completed = false;
            foreach (var line in command.stdout.split ("\n")) {
                if (line == "")
                    continue;
                if (line == "S\tOK") {
                    if (completed) {
                        return CompatibilityProcessInspectionResult.unknown (
                            "The Flatpak host process query returned duplicate completion records."
                        );
                    }
                    completed = true;
                    continue;
                }
                if (completed) {
                    return CompatibilityProcessInspectionResult.unknown (
                        "The Flatpak host process query returned data after completion."
                    );
                }

                var fields = line.split ("\t", 4);
                int pid = 0;
                if (fields.length != 4 || fields[0] != "R" ||
                    !int.try_parse (fields[1], out pid) || pid <= 0) {
                    return CompatibilityProcessInspectionResult.unknown (
                        "The Flatpak host process query returned malformed output."
                    );
                }
                uint8[] executable_bytes = {};
                var executable_available = fields[2] != "-";
                if (executable_available &&
                    (!decode_base64_field (fields[2], out executable_bytes) ||
                    executable_bytes.length == 0)) {
                    return CompatibilityProcessInspectionResult.unknown (
                        "The Flatpak host process query returned malformed process data."
                    );
                }
                uint8[] command_line = {};
                var command_line_available = fields[3] != "-";
                if (command_line_available &&
                    (!decode_base64_field (fields[3], out command_line) ||
                    command_line.length == 0 ||
                    !CompatibilityProcessRecord.cmdline_is_valid (command_line))) {
                    return CompatibilityProcessInspectionResult.unknown (
                        "The Flatpak host process query returned malformed process data."
                    );
                }
                var executable = executable_available
                    ? Utils.Parser.data_to_string (executable_bytes) : "";
                if (executable_available && !executable.validate ()) {
                    return CompatibilityProcessInspectionResult.unknown (
                        "The Flatpak host process query returned malformed executable data."
                    );
                }
                if (executable_available && command_line_available) {
                    records.add (new CompatibilityProcessRecord.from_cmdline_bytes (
                        pid, executable, command_line
                    ));
                } else if (command_line_available) {
                    records.add (new CompatibilityProcessRecord.with_unreadable_executable (
                        pid, command_line,
                        "Unable to inspect the executable of same-user host process %d.".printf (pid)
                    ));
                } else if (executable_available) {
                    records.add (new CompatibilityProcessRecord.with_unreadable_argv (
                        pid, executable,
                        "Unable to inspect the command line of same-user host process %d.".printf (pid)
                    ));
                } else {
                    records.add (new CompatibilityProcessRecord.with_unreadable_metadata (
                        pid,
                        "Unable to inspect the executable and command line of same-user host process %d.".printf (pid)
                    ));
                }
            }
            if (!completed) {
                return CompatibilityProcessInspectionResult.unknown (
                    "The Flatpak host process query did not report a completed scan."
                );
            }
            return CompatibilityProcessInspectionResult.clear (records);
        }

        private static bool decode_base64_field (string encoded, out uint8[] decoded) {
            decoded = Base64.decode (encoded);
            return encoded.length % 4 == 0 && Base64.encode (decoded) == encoded;
        }
    }

    public class CompatibilityProcessGuard : Object {
        private CompatibilityProcessQueryBackend backend;

        public CompatibilityProcessGuard (CompatibilityProcessQueryBackend? backend = null) {
            this.backend = backend ?? new NativeCompatibilityProcessQueryBackend ();
        }

        public CompatibilityProcessGuard.for_package (bool is_flatpak) {
            if (is_flatpak)
                backend = new FlatpakCompatibilityProcessQueryBackend ();
            else
                backend = new NativeCompatibilityProcessQueryBackend ();
        }

        public async CompatibilityProcessInspectionResult inspect (
            CompatibilityProcessOperationContext context
        ) {
            var observation = yield backend.inspect_processes ();
            if (observation.status == CompatibilityProcessInspectionStatus.UNKNOWN)
                return observation;
            return inspect_records (observation.processes, context);
        }

        public static CompatibilityProcessInspectionResult inspect_records (
            Gee.List<CompatibilityProcessRecord> processes,
            CompatibilityProcessOperationContext context
        ) {
            if (!context.mutates_existing_destination)
                return CompatibilityProcessInspectionResult.clear ();

            foreach (var process in processes) {
                var reason = target_association_reason (process, context.installation_path);
                if (reason != CompatibilityProcessMatchReason.NONE)
                    return CompatibilityProcessInspectionResult.active (process, reason);
            }
            foreach (var process in processes) {
                if (incomplete_evidence_could_associate_with_target (
                    process, context.installation_path
                )) {
                    return CompatibilityProcessInspectionResult.unknown (
                        process.inspection_error ??
                        "Process %d returned incomplete process metadata.".printf (process.pid)
                    );
                }
            }
            return CompatibilityProcessInspectionResult.clear ();
        }

        public static bool is_compatibility_process (CompatibilityProcessRecord process) {
            if (is_runner_token (process.executable_path))
                return true;

            foreach (var argument in process.argv) {
                if (is_runner_token (argument))
                    return true;
            }
            return false;
        }

        private static bool is_runner_token (string value) {
            var basename = Path.get_basename (value).ascii_down ();
            return basename == "proton" || basename == "umu" || basename == "umu-run" ||
                basename == "wine" || basename == "wine64" ||
                basename == "wine-preloader" || basename == "wine64-preloader" ||
                basename == "wineserver";
        }

        private static CompatibilityProcessMatchReason target_association_reason (
            CompatibilityProcessRecord process,
            string installation_path
        ) {
            if (process.executable_available &&
                path_is_within (process.executable_path, installation_path))
                return CompatibilityProcessMatchReason.EXECUTABLE_IN_TARGET;

            /* When procfs withholds the executable link, argv[0] is the best
             * available executable-path evidence.  It remains a distinct token
             * and receives the same exact target-boundary check. */
            if (!process.executable_available && process.argv_available &&
                process.argv.size > 0 &&
                path_is_within (process.argv[0], installation_path))
                return CompatibilityProcessMatchReason.EXECUTABLE_IN_TARGET;

            /* An argument path supports association only for a recognized
             * compatibility process.  This keeps a native editor opening an
             * .exe (including one under the tool directory) from becoming a
             * false blocker, while retaining interpreter + runner-script and
             * Wine/Proton + Windows-executable evidence. */
            if (!process.argv_available || !is_compatibility_process (process))
                return CompatibilityProcessMatchReason.NONE;
            foreach (var argument in process.argv) {
                if (path_is_within (argument, installation_path))
                    return CompatibilityProcessMatchReason.ARGUMENT_PATH_IN_TARGET;
            }
            return CompatibilityProcessMatchReason.NONE;
        }

        private static bool incomplete_evidence_could_associate_with_target (
            CompatibilityProcessRecord process,
            string installation_path
        ) {
            if (process.has_complete_metadata ())
                return false;

            if (!process.executable_available && !process.argv_available)
                return true;

            if (!process.executable_available) {
                /* Absolute runner tokens outside this target identify another
                 * installation.  A relative runner token does not provide
                 * enough path evidence to rule this target out. */
                foreach (var argument in process.argv) {
                    if (is_runner_token (argument) && !Path.is_absolute (argument))
                        return true;
                }
                return false;
            }

            /* A missing argv is relevant for interpreters and command wrappers
             * which can execute a target-owned runner script.  A readable,
             * unrelated native executable such as systemd is sufficient to
             * classify the process as unrelated. */
            return executable_can_launch_runner_argument (process.executable_path);
        }

        private static bool executable_can_launch_runner_argument (string executable) {
            var basename = Path.get_basename (executable).ascii_down ();
            return basename == "env" || basename == "sh" || basename == "bash" ||
                basename == "dash" || basename == "zsh" || basename == "fish" ||
                basename == "perl" || basename.has_prefix ("python");
        }

        private static bool path_is_within (string candidate, string target) {
            if (!Path.is_absolute (candidate) || target == "")
                return false;

            var cleaned = candidate;
            if (cleaned.has_suffix (" (deleted)"))
                cleaned = cleaned.substring (0, cleaned.length - " (deleted)".length);
            var canonical = Filename.canonicalize (cleaned, null);
            var resolved = Posix.realpath (canonical);
            var normalized = resolved ?? canonical;
            return normalized == target || normalized.has_prefix (target + Path.DIR_SEPARATOR_S);
        }
    }
}
