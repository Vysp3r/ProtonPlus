namespace ProtonPlus.Services {
    using ProtonPlus.Models;

    public enum SteamSessionState {
        STOPPED,
        STARTING,
        RUNNING,
        UPDATING,
        SHUTTING_DOWN,
        UNKNOWN
    }

    public enum SteamSessionBlocker {
        NONE,
        GAME_OR_COMPATIBILITY_PROCESS,
        STEAM_UPDATE_PROCESS,
        STARTUP_IN_PROGRESS,
        UNKNOWN_PROCESS_STATE
    }

    public enum SteamEvidenceLevel {
        NONE,
        HEURISTIC,
        CONFIRMED
    }

    public enum SteamSessionMode {
        UNKNOWN,
        STEAMOS_GAMING_MODE
    }

    public class SteamProcessGeneration : Object {
        public int pid { get; private set; }
        public int64 start_time_ticks { get; private set; }
        public string? boot_id { get; private set; }

        public SteamProcessGeneration (int pid, int64 start_time_ticks, string? boot_id) {
            this.pid = pid;
            this.start_time_ticks = start_time_ticks;
            this.boot_id = boot_id;
        }

        public string describe () {
            return ("%s:%" + int64.FORMAT + ":%d").printf (boot_id ?? "unknown-boot", start_time_ticks, pid);
        }
    }

    public class SteamSessionBlockerEvidence : Object {
        public SteamSessionBlocker blocker { get; private set; }
        public SteamEvidenceLevel confidence { get; private set; }
        public string detail { get; private set; }

        public SteamSessionBlockerEvidence (SteamSessionBlocker blocker, SteamEvidenceLevel confidence, string detail) {
            this.blocker = blocker;
            this.confidence = confidence;
            this.detail = detail;
        }
    }

    public class SteamRelaunchMetadata : Object {
        public string? desktop_entry_id { get; private set; }
        public string? desktop_entry_path { get; private set; }
        public string? flatpak_application_id { get; private set; }
        public bool steam_uri_handler_candidate { get; private set; }
        public string limitation { get; private set; }

        public SteamRelaunchMetadata (
            string? desktop_entry_id, string? desktop_entry_path, string? flatpak_application_id,
            bool steam_uri_handler_candidate, string limitation
        ) {
            this.desktop_entry_id = desktop_entry_id;
            this.desktop_entry_path = desktop_entry_path;
            this.flatpak_application_id = flatpak_application_id;
            this.steam_uri_handler_candidate = steam_uri_handler_candidate;
            this.limitation = limitation;
        }
    }

    public class SteamSessionSnapshot : Object {
        public string target_id { get; private set; }
        public SteamSessionState state { get; private set; }
        public bool matching_process_found { get; private set; }
        /* Zero denotes an unknown PID; it is not a valid Linux process ID. */
        public int main_process_pid { get; private set; }
        public bool main_process_pid_known { get { return main_process_pid > 0; } }
        public SteamProcessGeneration? generation { get; private set; }
        public string? flatpak_instance_id { get; private set; }
        public string? matching_executable_path { get; private set; }
        public SteamRelaunchMetadata relaunch { get; private set; }
        public Gee.List<SteamSessionBlockerEvidence> blockers { get; private set; }
        public SteamEvidenceLevel state_confidence { get; private set; }
        public SteamSessionMode session_mode { get; private set; }
        public Gee.List<string> diagnostics { get; private set; }

        public SteamSessionSnapshot (
            string target_id, SteamSessionState state, bool matching_process_found,
            int main_process_pid, SteamProcessGeneration? generation,
            string? flatpak_instance_id, string? matching_executable_path,
            SteamRelaunchMetadata relaunch, Gee.List<SteamSessionBlockerEvidence> blockers,
            SteamEvidenceLevel state_confidence, SteamSessionMode session_mode,
            Gee.List<string> diagnostics
        ) {
            this.target_id = target_id;
            this.state = state;
            this.matching_process_found = matching_process_found;
            this.main_process_pid = main_process_pid;
            this.generation = generation;
            this.flatpak_instance_id = flatpak_instance_id;
            this.matching_executable_path = matching_executable_path;
            this.relaunch = relaunch;
            this.blockers = blockers;
            this.state_confidence = state_confidence;
            this.session_mode = session_mode;
            this.diagnostics = diagnostics;
        }
    }

    /* Backends make every observation source fixtureable.  The service has no
     * process-control or filesystem-mutating member, by design. */
    public class SteamProcessRecord : Object {
        public int pid { get; private set; }
        public string executable_path { get; private set; }
        public string command_line { get; private set; }
        public int64 start_time_ticks { get; private set; }

        public SteamProcessRecord (int pid, string executable_path, string command_line, int64 start_time_ticks) {
            this.pid = pid;
            this.executable_path = executable_path;
            this.command_line = command_line;
            this.start_time_ticks = start_time_ticks;
        }

        public SteamProcessRecord.from_proc (
            int pid, string executable_path, uint8[] command_line_bytes, int64 start_time_ticks
        ) {
            this.pid = pid;
            this.executable_path = executable_path;
            this.command_line = decode_proc_command_line (command_line_bytes);
            this.start_time_ticks = start_time_ticks;
        }

        private static string decode_proc_command_line (uint8[] contents) {
            var decoded = new StringBuilder.sized (contents.length);
            foreach (var byte_value in contents)
                decoded.append_c (byte_value == 0 ? ' ' : (char) byte_value);
            return decoded.str.strip ();
        }
    }

    public class NativeProcessQuery : Object {
        public bool available { get; private set; }
        public Gee.List<SteamProcessRecord> processes { get; private set; }
        public string diagnostic { get; private set; }

        public NativeProcessQuery (bool available, Gee.List<SteamProcessRecord>? processes = null, string diagnostic = "") {
            this.available = available;
            this.processes = processes ?? new Gee.ArrayList<SteamProcessRecord> ();
            this.diagnostic = diagnostic;
        }
    }

    public class FlatpakProcessRecord : Object {
        public string instance_id { get; private set; }
        public string application_id { get; private set; }
        public int wrapper_pid { get; private set; }
        public int child_pid { get; private set; }

        public FlatpakProcessRecord (string instance_id, string application_id, int wrapper_pid, int child_pid) {
            this.instance_id = instance_id;
            this.application_id = application_id;
            this.wrapper_pid = wrapper_pid;
            this.child_pid = child_pid;
        }
    }

    public class FlatpakProcessQuery : Object {
        public bool available { get; private set; }
        public Gee.List<FlatpakProcessRecord> processes { get; private set; }
        public string diagnostic { get; private set; }

        public FlatpakProcessQuery (bool available, Gee.List<FlatpakProcessRecord>? processes = null, string diagnostic = "") {
            this.available = available;
            this.processes = processes ?? new Gee.ArrayList<FlatpakProcessRecord> ();
            this.diagnostic = diagnostic;
        }
    }

    public class SteamDesktopEntry : Object {
        public string id { get; private set; }
        public string path { get; private set; }
        public bool supports_steam_uri { get; private set; }

        public SteamDesktopEntry (string id, string path, bool supports_steam_uri) {
            this.id = id;
            this.path = path;
            this.supports_steam_uri = supports_steam_uri;
        }
    }

    public interface SteamSessionBackend : Object {
        public abstract string? get_boot_id ();
        public abstract int64 get_monotonic_time_usec ();
        public abstract int64 get_clock_ticks_per_second ();
        public abstract NativeProcessQuery query_native_processes ();
        public abstract FlatpakProcessQuery query_flatpak_processes ();
        public abstract SteamDesktopEntry? find_desktop_entry (string? id);
        public abstract bool is_steamos_gaming_mode ();
    }

    private class HostSteamSessionBackend : Object, SteamSessionBackend {
        public string? get_boot_id () {
            string content;
            try {
                FileUtils.get_contents ("/proc/sys/kernel/random/boot_id", out content);
                return content.strip ();
            } catch (FileError e) {
                return null;
            }
        }

        public int64 get_monotonic_time_usec () {
            return get_monotonic_time ();
        }

        public int64 get_clock_ticks_per_second () {
            var ticks = Posix.sysconf (Posix._SC_CLK_TCK);
            return ticks > 0 ? ticks : 0;
        }

        public NativeProcessQuery query_native_processes () {
            var processes = new Gee.ArrayList<SteamProcessRecord> ();
            try {
                var directory = File.new_for_path ("/proc").enumerate_children ("standard::name", FileQueryInfoFlags.NONE, null);
                FileInfo? info;
                while ((info = directory.next_file (null)) != null) {
                    var name = info.get_name ();
                    if (name.length == 0 || !name.get_char (0).isdigit ())
                        continue;
                    var pid = int.parse (name);
                    var root = "/proc/%d".printf (pid);
                    uint8[] command;
                    try {
                        FileUtils.get_data (Path.build_filename (root, "cmdline"), out command);
                    } catch (FileError e) {
                        continue;
                    }
                    string executable;
                    try {
                        executable = FileUtils.read_link (Path.build_filename (root, "exe"));
                    } catch (FileError e) {
                        continue;
                    }
                    var start_time = read_start_time (Path.build_filename (root, "stat"));
                    processes.add (new SteamProcessRecord.from_proc (pid, executable, command, start_time));
                }
                return new NativeProcessQuery (true, processes);
            } catch (Error e) {
                return new NativeProcessQuery (false, processes, "Unable to inspect /proc: %s".printf (e.message));
            }
        }

        private int64 read_start_time (string path) {
            string stat;
            try {
                FileUtils.get_contents (path, out stat);
                var closing = stat.last_index_of_char (')');
                if (closing < 0)
                    return 0;
                var fields = stat.substring (closing + 1).strip ().split (" ");
                if (fields.length <= 19)
                    return 0;
                return int64.parse (fields[19]);
            } catch (FileError e) {
                return 0;
            }
        }

        public FlatpakProcessQuery query_flatpak_processes () {
            var result = Utils.System.run_command_sync_result ("flatpak ps --columns=instance,application,pid,child-pid");
            if (result.exit_status != 0)
                return new FlatpakProcessQuery (false, null, "flatpak ps is unavailable (%d).".printf (result.exit_status));
            var processes = new Gee.ArrayList<FlatpakProcessRecord> ();
            foreach (var line in result.stdout.split ("\n")) {
                var stripped = line.strip ();
                if (stripped == "")
                    continue;
                var fields = stripped.split ("\t");
                int wrapper_pid = 0;
                int child_pid = 0;
                if (fields.length != 4 || fields[0] == "" || fields[1] == ""
                    || !int.try_parse (fields[2], out wrapper_pid)
                    || !int.try_parse (fields[3], out child_pid)) {
                    return new FlatpakProcessQuery (false, processes, "flatpak ps returned incomplete process metadata.");
                }
                processes.add (new FlatpakProcessRecord (fields[0], fields[1], wrapper_pid, child_pid));
            }
            return new FlatpakProcessQuery (true, processes);
        }

        public SteamDesktopEntry? find_desktop_entry (string? id) {
            if (id == null || id == "")
                return null;
            var paths = new string[] {
                Path.build_filename (Environment.get_user_data_dir (), "applications", id),
                Path.build_filename ("/usr/share/applications", id)
            };
            foreach (var path in paths) {
                if (!FileUtils.test (path, FileTest.IS_REGULAR))
                    continue;
                string content;
                try {
                    FileUtils.get_contents (path, out content);
                    return new SteamDesktopEntry (id, path, content.contains ("x-scheme-handler/steam"));
                } catch (FileError e) {
                    continue;
                }
            }
            return null;
        }

        public bool is_steamos_gaming_mode () {
            return environment_identifies_gamescope ("XDG_CURRENT_DESKTOP")
                || environment_identifies_gamescope ("XDG_SESSION_DESKTOP")
                || environment_identifies_gamescope ("DESKTOP_SESSION");
        }

        private bool environment_identifies_gamescope (string name) {
            var value = Environment.get_variable (name);
            return value != null && ((!) value).down ().contains ("gamescope");
        }
    }

    public class SteamSessionService : Object {
        private const int64 STARTING_WINDOW_USEC = 30 * 1000 * 1000;
        private SteamSessionBackend backend;
        private Gee.ArrayList<SteamRestartTarget> monitored_targets = new Gee.ArrayList<SteamRestartTarget> ();
        private Gee.HashMap<string, SteamSessionSnapshot> previous_monitored_snapshots = new Gee.HashMap<string, SteamSessionSnapshot> ();
        private uint monitoring_source_id = 0;

        private static SteamSessionService? _instance;
        public static SteamSessionService instance {
            get {
                if (_instance == null)
                    _instance = new SteamSessionService ();
                return (!) _instance;
            }
        }

        public signal void state_changed (SteamRestartTarget target, SteamSessionSnapshot snapshot);

        public SteamSessionService (SteamSessionBackend? backend = null) {
            this.backend = backend ?? new HostSteamSessionBackend ();
        }

        public bool is_monitoring { get { return monitoring_source_id != 0; } }

        public void watch_target (SteamRestartTarget target) {
            foreach (var existing in monitored_targets) {
                if (existing.id == target.id)
                    return;
            }
            monitored_targets.add (target);
        }

        public SteamSessionSnapshot inspect (SteamRestartTarget target) {
            var diagnostics = new Gee.ArrayList<string> ();
            var blockers = new Gee.ArrayList<SteamSessionBlockerEvidence> ();
            var relaunch = get_relaunch_metadata (target);
            var session_mode = backend.is_steamos_gaming_mode ()
                ? SteamSessionMode.STEAMOS_GAMING_MODE : SteamSessionMode.UNKNOWN;

            switch (target.installation_kind) {
            case SteamInstallationKind.FLATPAK:
                return inspect_flatpak (target, relaunch, blockers, diagnostics, session_mode);
            case SteamInstallationKind.NATIVE:
            case SteamInstallationKind.SNAP:
                return inspect_native (target, relaunch, blockers, diagnostics, session_mode);
            default:
                diagnostics.add ("This target has no reliable process observation strategy.");
                blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.UNKNOWN_PROCESS_STATE, SteamEvidenceLevel.CONFIRMED, diagnostics[0]));
                return snapshot (target, SteamSessionState.UNKNOWN, false, 0, null, null, null, relaunch, blockers, SteamEvidenceLevel.NONE, session_mode, diagnostics);
            }
        }

        public Gee.List<SteamSessionSnapshot> inspect_all (Gee.List<SteamRestartTarget> targets) {
            var snapshots = new Gee.ArrayList<SteamSessionSnapshot> ();
            foreach (var target in targets)
                snapshots.add (inspect (target));
            return snapshots;
        }

        public void start_monitoring () {
            if (monitoring_source_id != 0)
                return;
            monitoring_source_id = Timeout.add_seconds (5, () => {
                poll_monitored ();
                return Source.CONTINUE;
            });
        }

        public void stop_monitoring () {
            if (monitoring_source_id != 0) {
                Source.remove (monitoring_source_id);
                monitoring_source_id = 0;
            }
            previous_monitored_snapshots.clear ();
        }

        /* A synchronous read-only poll is useful to lifecycle owners and tests;
         * monitoring never owns a window, banner, or UI timeout. */
        public void poll_monitored () {
            foreach (var target in monitored_targets) {
                var observed = inspect (target);
                var previous = previous_monitored_snapshots.get (target.id);
                if (previous != null && previous.matching_process_found
                    && observed.state == SteamSessionState.STOPPED) {
                    observed = new SteamSessionSnapshot (
                        observed.target_id, SteamSessionState.SHUTTING_DOWN, false, 0, null,
                        observed.flatpak_instance_id, observed.matching_executable_path,
                        observed.relaunch, observed.blockers, SteamEvidenceLevel.HEURISTIC,
                        observed.session_mode,
                        observed.diagnostics
                    );
                    observed.diagnostics.add ("A previously observed Steam anchor disappeared during monitoring.");
                }
                previous_monitored_snapshots.set (target.id, observed);
                state_changed (target, observed);
            }
        }

        private SteamSessionSnapshot inspect_native (
            SteamRestartTarget target, SteamRelaunchMetadata relaunch,
            Gee.List<SteamSessionBlockerEvidence> blockers, Gee.List<string> diagnostics,
            SteamSessionMode session_mode
        ) {
            var query = backend.query_native_processes ();
            if (!query.available) {
                diagnostics.add (query.diagnostic);
                blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.UNKNOWN_PROCESS_STATE, SteamEvidenceLevel.CONFIRMED, query.diagnostic));
                return snapshot (target, SteamSessionState.UNKNOWN, false, 0, null, null, null, relaunch, blockers, SteamEvidenceLevel.NONE, session_mode, diagnostics);
            }

            var anchors = new Gee.ArrayList<SteamProcessRecord> ();
            foreach (var process in query.processes) {
                if (is_associated (target, process))
                    collect_blocker (target, process, blockers);
                if (!is_anchor (target, process))
                    continue;
                anchors.add (process);
            }

            SteamProcessRecord? anchor = null;
            var runtime_update_transition = false;
            if (anchors.size == 1)
                anchor = anchors[0];
            else if (anchors.size > 1) {
                anchor = select_runtime_duplicate_anchor (anchors);
                if (anchor == null) {
                    anchor = select_runtime_update_anchor (anchors);
                    runtime_update_transition = anchor != null;
                }
                if (anchor == null) {
                    diagnostics.add ("More than one native Steam anchor matched this physical target.");
                    blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.UNKNOWN_PROCESS_STATE, SteamEvidenceLevel.CONFIRMED, diagnostics[diagnostics.size - 1]));
                    return snapshot (target, SteamSessionState.UNKNOWN, true, 0, null, null, null, relaunch, blockers, SteamEvidenceLevel.NONE, session_mode, diagnostics);
                }
                diagnostics.add (runtime_update_transition
                    ? "Native Steam Runtime client and update UI anchors were identified during an update handoff."
                    : "Multiple native Steam Runtime anchors shared the same executable and command line; selected the earliest process generation.");
            }
            if (anchor == null) {
                diagnostics.add ("No native Steam anchor matched the target root.");
                return snapshot (target, SteamSessionState.STOPPED, false, 0, null, null, null, relaunch, blockers, SteamEvidenceLevel.CONFIRMED, session_mode, diagnostics);
            }

            if (anchor.start_time_ticks <= 0 || backend.get_boot_id () == null) {
                diagnostics.add ("Steam anchor was found, but generation metadata is incomplete.");
                blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.UNKNOWN_PROCESS_STATE, SteamEvidenceLevel.CONFIRMED, diagnostics[diagnostics.size - 1]));
                return snapshot (target, SteamSessionState.UNKNOWN, true, anchor.pid, null, null, anchor.executable_path, relaunch, blockers, SteamEvidenceLevel.HEURISTIC, session_mode, diagnostics);
            }

            var generation = new SteamProcessGeneration (anchor.pid, anchor.start_time_ticks, backend.get_boot_id ());
            var state = SteamSessionState.RUNNING;
            if (runtime_update_transition || is_explicit_updater (anchor)) {
                state = SteamSessionState.UPDATING;
                blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.STEAM_UPDATE_PROCESS, SteamEvidenceLevel.HEURISTIC, "Steam anchor command identifies update/bootstrap activity."));
            } else if (is_recent (anchor)) {
                state = SteamSessionState.STARTING;
                blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.STARTUP_IN_PROGRESS, SteamEvidenceLevel.HEURISTIC, "Steam anchor has not passed the configured stabilization window."));
            }
            diagnostics.add ("Native Steam anchor identified from executable and target-root evidence.");
            return snapshot (target, state, true, anchor.pid, generation, null, anchor.executable_path, relaunch, blockers, SteamEvidenceLevel.CONFIRMED, session_mode, diagnostics);
        }

        private SteamSessionSnapshot inspect_flatpak (
            SteamRestartTarget target, SteamRelaunchMetadata relaunch,
            Gee.List<SteamSessionBlockerEvidence> blockers, Gee.List<string> diagnostics,
            SteamSessionMode session_mode
        ) {
            var query = backend.query_flatpak_processes ();
            if (!query.available) {
                diagnostics.add (query.diagnostic);
                blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.UNKNOWN_PROCESS_STATE, SteamEvidenceLevel.CONFIRMED, query.diagnostic));
                return snapshot (target, SteamSessionState.UNKNOWN, false, 0, null, null, null, relaunch, blockers, SteamEvidenceLevel.NONE, session_mode, diagnostics);
            }
            FlatpakProcessRecord? match = null;
            foreach (var process in query.processes) {
                if (process.application_id != target.flatpak_application_id)
                    continue;
                if (match != null) {
                    diagnostics.add ("More than one Flatpak Steam instance matched the exact application ID.");
                    return snapshot (target, SteamSessionState.UNKNOWN, true, 0, null, null, null, relaunch, blockers, SteamEvidenceLevel.NONE, session_mode, diagnostics);
                }
                match = process;
            }
            if (match == null) {
                diagnostics.add ("No Flatpak Steam process matched the exact application ID.");
                return snapshot (target, SteamSessionState.STOPPED, false, 0, null, null, null, relaunch, blockers, SteamEvidenceLevel.CONFIRMED, session_mode, diagnostics);
            }
            var pid = match.child_pid > 0 ? match.child_pid : match.wrapper_pid;
            var generation = new SteamProcessGeneration (pid, 0, backend.get_boot_id ());
            diagnostics.add ("Flatpak Steam process matched the exact application ID; UI readiness is not inferred.");
            return snapshot (target, SteamSessionState.RUNNING, true, pid, generation, match.instance_id, null, relaunch, blockers, SteamEvidenceLevel.CONFIRMED, session_mode, diagnostics);
        }

        private SteamSessionSnapshot snapshot (
            SteamRestartTarget target, SteamSessionState state, bool found, int pid,
            SteamProcessGeneration? generation, string? instance, string? executable,
            SteamRelaunchMetadata relaunch, Gee.List<SteamSessionBlockerEvidence> blockers,
            SteamEvidenceLevel confidence, SteamSessionMode session_mode,
            Gee.List<string> diagnostics
        ) {
            return new SteamSessionSnapshot (target.id, state, found, pid, generation, instance, executable,
                                             relaunch, blockers, confidence, session_mode, diagnostics);
        }

        private SteamRelaunchMetadata get_relaunch_metadata (SteamRestartTarget target) {
            var entry = backend.find_desktop_entry (target.desktop_entry_id);
            var limitation = "Candidate metadata only; this phase does not execute a relaunch strategy.";
            if (target.installation_kind == SteamInstallationKind.CUSTOM || target.installation_kind == SteamInstallationKind.UNKNOWN)
                limitation = "Custom or unknown Steam environments have no supported relaunch inference.";
            return new SteamRelaunchMetadata (entry != null ? entry.id : target.desktop_entry_id,
                                               entry != null ? entry.path : null,
                                               target.flatpak_application_id,
                                               entry != null && entry.supports_steam_uri,
                                               limitation);
        }

        private bool is_anchor (SteamRestartTarget target, SteamProcessRecord process) {
            if (!is_associated (target, process))
                return false;
            return Path.get_basename (process.executable_path).down () == "steam";
        }

        /* Current native Steam Runtime can retain a bootstrap Steam process
         * alongside the client process.  It is safe to collapse only this
         * exact, documented shape: every candidate must be the same executable
         * with the same Runtime invocation.  Any other multiplicity remains
         * ambiguous rather than risking a restart against the wrong client. */
        private SteamProcessRecord? select_runtime_duplicate_anchor (Gee.List<SteamProcessRecord> candidates) {
            SteamProcessRecord? selected = null;
            foreach (var candidate in candidates) {
                if (!candidate.command_line.contains ("-srt-logger-opened"))
                    return null;
                if (selected != null) {
                    var current = (!) selected;
                    if (candidate.executable_path != current.executable_path
                        || candidate.command_line != current.command_line)
                        return null;
                    if (candidate.start_time_ticks > current.start_time_ticks
                        || (candidate.start_time_ticks == current.start_time_ticks && candidate.pid > current.pid))
                        continue;
                }
                selected = candidate;
            }
            return selected;
        }

        /* During a self-update Steam can run its ordinary Runtime anchor and a
         * child update-UI anchor from the same executable.  This shape is not
         * a stable running client, but it is specific enough to classify as an
         * update instead of losing the lifecycle in generic ambiguity. */
        private SteamProcessRecord? select_runtime_update_anchor (Gee.List<SteamProcessRecord> candidates) {
            var regular = new Gee.ArrayList<SteamProcessRecord> ();
            string? executable = null;
            var updater_found = false;
            foreach (var candidate in candidates) {
                if (!candidate.command_line.contains ("-srt-logger-opened"))
                    return null;
                if (executable != null && candidate.executable_path != (!) executable)
                    return null;
                executable = candidate.executable_path;
                if (is_explicit_updater (candidate))
                    updater_found = true;
                else
                    regular.add (candidate);
            }
            if (!updater_found)
                return null;
            if (regular.size == 1)
                return regular[0];
            if (regular.size > 1)
                return select_runtime_duplicate_anchor (regular);

            SteamProcessRecord? selected = null;
            foreach (var candidate in candidates) {
                if (selected == null
                    || candidate.start_time_ticks < ((!) selected).start_time_ticks
                    || (candidate.start_time_ticks == ((!) selected).start_time_ticks
                        && candidate.pid < ((!) selected).pid))
                    selected = candidate;
            }
            return selected;
        }

        private bool is_associated (SteamRestartTarget target, SteamProcessRecord process) {
            return process.executable_path == target.data_root
                   || process.executable_path.has_prefix (target.data_root + "/")
                   || process.command_line.contains (target.data_root);
        }

        private void collect_blocker (SteamRestartTarget target, SteamProcessRecord process, Gee.List<SteamSessionBlockerEvidence> blockers) {
            var executable = Path.get_basename (process.executable_path).down ();
            var command = process.command_line.down ();
            if (executable == "proton" || executable == "umu" || executable == "wine" || executable == "wine64") {
                blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.GAME_OR_COMPATIBILITY_PROCESS, SteamEvidenceLevel.CONFIRMED, "A compatibility runner is associated with this Steam target."));
            } else if (command.contains (".exe")) {
                blockers.add (new SteamSessionBlockerEvidence (SteamSessionBlocker.GAME_OR_COMPATIBILITY_PROCESS, SteamEvidenceLevel.HEURISTIC, "An associated command includes a Windows executable marker."));
            }
        }

        private bool is_explicit_updater (SteamProcessRecord process) {
            var command = process.command_line.down ();
            return command.contains ("-update") || command.contains ("steambootstrapper");
        }

        private bool is_recent (SteamProcessRecord process) {
            var ticks_per_second = backend.get_clock_ticks_per_second ();
            if (ticks_per_second <= 0)
                return false;
            var now = backend.get_monotonic_time_usec ();
            var started_usec = process.start_time_ticks * 1000 * 1000 / ticks_per_second;
            return process.start_time_ticks > 0 && now >= started_usec
                   && now - started_usec < STARTING_WINDOW_USEC;
        }
    }
}
