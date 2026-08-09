namespace ProtonPlus.Utils {
    using ProtonPlus.Models;

    public enum GpuVendor {
        UNKNOWN,
        AMD,
        NVIDIA,
        INTEL
    }

    public class CommandResult : Object {
        public string stdout { get; private set; }
        public string stderr { get; private set; }
        public int exit_status { get; private set; }

        public CommandResult (string stdout, string stderr, int exit_status) {
            this.stdout = stdout;
            this.stderr = stderr;
            this.exit_status = exit_status;
        }
    }

    public interface SystemctlBackend : Object {
        public abstract async CommandResult run (string arguments);
    }

    private class HostSystemctlBackend : Object, SystemctlBackend {
        public async CommandResult run (string arguments) {
            return yield System.run_command ("systemctl --user " + arguments);
        }
    }

    public class SystemdTimerManager : Object {
        private const string TIMER_UNIT = "protonplus.timer";
        private SystemctlBackend backend;
        private string systemd_dir;
        private string service_template;
        private string timer_template;
        private string exec_start;

        public SystemdTimerManager (
            SystemctlBackend backend,
            string systemd_dir,
            string service_template,
            string timer_template,
            string exec_start
        ) {
            this.backend = backend;
            this.systemd_dir = systemd_dir;
            this.service_template = service_template;
            this.timer_template = timer_template;
            this.exec_start = exec_start;
        }

        public async bool reconcile (bool check_on_boot, bool background_updates, int frequency) {
            if (!check_on_boot && !background_updates)
                return yield reconcile_disabled ();

            bool files_changed;
            if (!write_unit_files (check_on_boot, background_updates, frequency, out files_changed))
                return false;

            if (files_changed && !(yield run_action ("daemon-reload")))
                return false;

            var enabled = (yield backend.run ("is-enabled --quiet " + TIMER_UNIT)).exit_status == 0;
            var active = (yield backend.run ("is-active --quiet " + TIMER_UNIT)).exit_status == 0;

            if (!enabled || !active) {
                if (!(yield run_action ("enable --now " + TIMER_UNIT)))
                    return false;

                /* Starting an inactive timer already loads the new schedule.
                 * An active but newly enabled timer still needs a restart when
                 * its unit contents changed. */
                if (!active)
                    return true;
            }

            if (files_changed)
                return yield run_action ("restart " + TIMER_UNIT);

            return true;
        }

        private async bool reconcile_disabled () {
            var files_present = unit_files_exist ();
            var enabled = (yield backend.run ("is-enabled --quiet " + TIMER_UNIT)).exit_status == 0;
            var active = (yield backend.run ("is-active --quiet " + TIMER_UNIT)).exit_status == 0;

            if ((files_present || enabled || active) && !(yield run_action ("disable --now " + TIMER_UNIT)))
                return false;

            bool files_removed;
            if (!remove_unit_files (out files_removed))
                return false;

            if (files_removed || enabled || active)
                return yield run_action ("daemon-reload");

            return true;
        }

        private bool unit_files_exist () {
            return FileUtils.test (Path.build_filename (systemd_dir, "protonplus.service"), FileTest.EXISTS)
                || FileUtils.test (Path.build_filename (systemd_dir, TIMER_UNIT), FileTest.EXISTS);
        }

        private bool write_unit_files (
            bool check_on_boot,
            bool background_updates,
            int frequency,
            out bool files_changed
        ) {
            files_changed = false;
            var on_unit_active_sec = "1h";
            switch (frequency) {
            case 1:
                on_unit_active_sec = "3h";
                break;
            case 2:
                on_unit_active_sec = "6h";
                break;
            case 3:
                on_unit_active_sec = "12h";
                break;
            case 0:
            default:
                break;
            }

            var service_content = service_template.replace ("{ExecStart}", exec_start);
            var timer_content = timer_template;
            if (!check_on_boot)
                timer_content = timer_content.replace ("OnBootSec=1min", "");
            if (background_updates)
                timer_content = timer_content.replace ("{OnUnitActiveSec}", on_unit_active_sec);
            else
                timer_content = timer_content.replace ("OnUnitActiveSec={OnUnitActiveSec}\n", "")
                    .replace ("OnUnitActiveSec={OnUnitActiveSec}", "");

            try {
                var dir = File.new_for_path (systemd_dir);
                if (!dir.query_exists ())
                    dir.make_directory_with_parents ();

                files_changed |= write_if_changed (
                    Path.build_filename (systemd_dir, "protonplus.service"), service_content
                );
                files_changed |= write_if_changed (
                    Path.build_filename (systemd_dir, TIMER_UNIT), timer_content
                );
                return true;
            } catch (Error e) {
                warning (e.message);
                return false;
            }
        }

        private bool write_if_changed (string path, string contents) throws FileError {
            if (FileUtils.test (path, FileTest.EXISTS)) {
                string existing;
                FileUtils.get_contents (path, out existing);
                if (existing == contents)
                    return false;
            }

            FileUtils.set_contents (path, contents);
            return true;
        }

        private bool remove_unit_files (out bool files_removed) {
            files_removed = false;
            try {
                foreach (var name in new string[] { "protonplus.service", TIMER_UNIT }) {
                    var file = File.new_for_path (Path.build_filename (systemd_dir, name));
                    if (!file.query_exists ())
                        continue;
                    file.delete ();
                    files_removed = true;
                }
                return true;
            } catch (Error e) {
                warning (e.message);
                return false;
            }
        }

        private async bool run_action (string arguments) {
            var command = "systemctl --user " + arguments;
            var result = yield backend.run (arguments);
            if (result.exit_status == 0)
                return true;

            var error_output = result.stderr.strip ();
            if (error_output == "")
                error_output = result.stdout.strip ();
            if (error_output == "")
                error_output = "no output";

            warning ("%s failed with exit status %d: %s", command, result.exit_status, error_output);
            return false;
        }
    }

    public class System {
        static bool systemd_update_running = false;
        static bool systemd_update_pending = false;
        static SystemdTimerManager? systemd_timer_manager = null;

        [CCode (cname = "ProtonPlusCpuFeatureProbe", cheader_filename = "utils/cpu-probe.h", has_type_id = false)]
        private struct CpuFeatureProbe {
            public bool available;
            public bool cmpxchg16b;
            public bool lahf_sahf;
            public bool popcnt;
            public bool sse3;
            public bool sse4_1;
            public bool sse4_2;
            public bool ssse3;
            public bool avx;
            public bool avx2;
            public bool bmi1;
            public bool bmi2;
            public bool f16c;
            public bool fma;
            public bool lzcnt;
            public bool movbe;
            public bool osxsave;
            public bool xcr0_xmm;
            public bool xcr0_ymm;
            public bool avx512f;
            public bool avx512bw;
            public bool avx512cd;
            public bool avx512dq;
            public bool avx512vl;
            public bool xcr0_opmask;
            public bool xcr0_zmm_hi256;
            public bool xcr0_hi16_zmm;
        }

        [CCode (cname = "protonplus_cpu_get_feature_probe", cheader_filename = "utils/cpu-probe.h", has_target = false)]
        private static extern CpuFeatureProbe get_cpu_feature_probe ();

        public static async CommandResult run_command (string command) {
            try {
                var argv = get_command_argv (command);

                var subprocess = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                Bytes stdout_bytes;
                Bytes stderr_bytes;
                yield subprocess.communicate_async (null, null, out stdout_bytes, out stderr_bytes);

                var stdout = stdout_bytes != null ? Parser.data_to_string (stdout_bytes.get_data ()) : "";
                var stderr = stderr_bytes != null ? Parser.data_to_string (stderr_bytes.get_data ()) : "";
                var exit_status = subprocess.get_if_exited () ? subprocess.get_exit_status () : -1;

                return new CommandResult (stdout, stderr, exit_status);
            } catch (Error e) {
                warning (e.message);
                return new CommandResult ("", e.message, -1);
            }
        }

        public static string run_command_sync (string command) {
            string output = "";
            try {
                var argv = get_command_argv (command);

                var subprocess = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_MERGE);
                Bytes stdout_bytes;
                subprocess.communicate (null, null, out stdout_bytes, null);

                if (stdout_bytes != null)
                    output = Parser.data_to_string (stdout_bytes.get_data ());
            } catch (Error e) {
                warning (e.message);
            }

            return output;
        }

        /* This remains a command-execution seam, but callers can distinguish
         * an unavailable read-only host query from a successful empty result. */
        public static CommandResult run_command_sync_result (string command) {
            string output = "";
            string error_output = "";
            var exit_status = -1;
            try {
                var argv = get_command_argv (command);

                var subprocess = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                Bytes stdout_bytes;
                Bytes stderr_bytes;
                subprocess.communicate (null, null, out stdout_bytes, out stderr_bytes);

                if (stdout_bytes != null)
                    output = Parser.data_to_string (stdout_bytes.get_data ());
                if (stderr_bytes != null)
                    error_output = Parser.data_to_string (stderr_bytes.get_data ());
                exit_status = subprocess.get_if_exited () ? subprocess.get_exit_status () : -1;
            } catch (Error e) {
                warning (e.message);
                error_output = e.message;
            }

            return new CommandResult (output, error_output, exit_status);
        }

        private static string[] get_command_argv (string command) throws ShellError {
            var command_line = Globals.IS_FLATPAK ? "flatpak-spawn --host " + command : command;
            string[] argv;
            Shell.parse_argv (command_line, out argv);
            return argv;
        }

        public static CpuArchitecture normalize_cpu_architecture (string machine) {
            switch (machine.strip ().ascii_down ()) {
            case "x86_64":
            case "amd64":
            case "x64":
            case "x86-64":
                return CpuArchitecture.X86_64;
            case "aarch64":
            case "arm64":
                return CpuArchitecture.AARCH64;
            case "i386":
            case "i486":
            case "i586":
            case "i686":
            case "x86":
            case "x86_32":
            case "ia32":
                return CpuArchitecture.X86_32;
            default:
                return CpuArchitecture.UNKNOWN;
            }
        }

        /// Supplies a host-independent seam for capability fixtures.  An
        /// unavailable detailed probe intentionally leaves an x86-64 host at
        /// the psABI baseline rather than guessing a newer ISA level.
        public static CpuCapabilities get_cpu_capabilities_for_probe (
            string machine,
            bool feature_probe_available,
            X86_64Features features
        ) {
            var architecture = normalize_cpu_architecture (machine);
            if (architecture != CpuArchitecture.X86_64)
                return new CpuCapabilities (architecture);

            var level = feature_probe_available
                ? CpuCapabilities.x86_64_level_from_features (features)
                : X86_64Level.BASELINE;
            return new CpuCapabilities (architecture, level);
        }

        private static X86_64Features get_x86_64_features (CpuFeatureProbe probe) {
            return new X86_64Features () {
                cmpxchg16b = probe.cmpxchg16b,
                lahf_sahf = probe.lahf_sahf,
                popcnt = probe.popcnt,
                sse3 = probe.sse3,
                sse4_1 = probe.sse4_1,
                sse4_2 = probe.sse4_2,
                ssse3 = probe.ssse3,
                avx = probe.avx,
                avx2 = probe.avx2,
                bmi1 = probe.bmi1,
                bmi2 = probe.bmi2,
                f16c = probe.f16c,
                fma = probe.fma,
                lzcnt = probe.lzcnt,
                movbe = probe.movbe,
                osxsave = probe.osxsave,
                xcr0_xmm = probe.xcr0_xmm,
                xcr0_ymm = probe.xcr0_ymm,
                avx512f = probe.avx512f,
                avx512bw = probe.avx512bw,
                avx512cd = probe.avx512cd,
                avx512dq = probe.avx512dq,
                avx512vl = probe.avx512vl,
                xcr0_opmask = probe.xcr0_opmask,
                xcr0_zmm_hi256 = probe.xcr0_zmm_hi256,
                xcr0_hi16_zmm = probe.xcr0_hi16_zmm
            };
        }

        public static CpuCapabilities get_cpu_capabilities () {
            var system_info = Posix.utsname ();
            var architecture = normalize_cpu_architecture (system_info.machine);
            if (architecture != CpuArchitecture.X86_64)
                return new CpuCapabilities (architecture);

            // CPUID establishes advertised CPU features; the C boundary reads
            // XCR0 only after OSXSAVE is set, so AVX and AVX-512 are reported
            // only when the operating system has enabled their register state.
            var probe = get_cpu_feature_probe ();
            return get_cpu_capabilities_for_probe (
                system_info.machine,
                probe.available,
                get_x86_64_features (probe)
            );
        }

        public static List<string> get_hwcaps_for_capabilities (CpuCapabilities capabilities) {
            var hwcaps = new List<string> ();

            switch (capabilities.architecture) {
            case CpuArchitecture.X86_64:
                if (capabilities.supports_x86_64_level (X86_64Level.V4))
                    hwcaps.append ("x86_64_v4");
                if (capabilities.supports_x86_64_level (X86_64Level.V3))
                    hwcaps.append ("x86_64_v3");
                if (capabilities.supports_x86_64_level (X86_64Level.V2))
                    hwcaps.append ("x86_64_v2");
                hwcaps.append ("x86_64");
                break;
            case CpuArchitecture.AARCH64:
                hwcaps.append ("aarch64");
                break;
            case CpuArchitecture.X86_32:
                hwcaps.append ("x86");
                break;
            default:
                hwcaps.append ("unknown");
                break;
            }

            return (owned) hwcaps;
        }

        public static List<string> get_hwcaps () {
            return get_hwcaps_for_capabilities (get_cpu_capabilities ());
        }

        public static async bool check_dependency (string name) {
            if (!Globals.IS_FLATPAK)
                return Environment.find_program_in_path (name) != null;

            var output = (yield run_command ("which %s".printf (Shell.quote (name)))).stdout;
            return output != "" && !output.contains ("which: no");
        }

        public static bool check_dependency_sync (string name) {
            if (!Globals.IS_FLATPAK)
                return Environment.find_program_in_path (name) != null;

            var output = run_command_sync ("which %s".printf (Shell.quote (name)));
            return output != "" && !output.contains ("which: no");
        }

        public static bool check_flatpak_dependency_sync (string name) {
            if (!Globals.IS_FLATPAK) {
                return false;
            }
            var output = run_command_sync ("flatpak info %s".printf (Shell.quote (name)));
            return output != "" && !output.contains ("error:");
        }

        public static GpuVendor get_gpu_vendor_from_pci_devices (string pci_devices) {
            foreach (var line in pci_devices.split ("\n")) {
                // Display controller PCI classes range from 0x0300 to 0x03ff.
                if (!line.contains ("[03"))
                    continue;

                if (line.contains ("[1002:"))
                    return GpuVendor.AMD;
                if (line.contains ("[10de:"))
                    return GpuVendor.NVIDIA;
                if (line.contains ("[8086:"))
                    return GpuVendor.INTEL;
            }

            return GpuVendor.UNKNOWN;
        }

        public static async GpuVendor detect_gpu_vendor () {
            if (!(yield check_dependency ("lspci")))
                return GpuVendor.UNKNOWN;

            var result = yield run_command ("lspci -nn");
            if (result.exit_status != 0)
                return GpuVendor.UNKNOWN;

            return get_gpu_vendor_from_pci_devices (result.stdout);
        }

        public static string get_distribution_name () {
            string distro_name = "Unknown";
            try {
                var file = File.new_for_path ("/etc/os-release");
                if (!file.query_exists ()) {
                    file = File.new_for_path ("/usr/lib/os-release");
                }

                if (file.query_exists ()) {
                    var dis = new DataInputStream (file.read ());
                    string line;
                    while ((line = dis.read_line ()) != null) {
                        if (line.has_prefix ("NAME=")) {
                            distro_name = line.substring (5).replace ("\"", "").replace ("'", "");
                            break;
                        }
                    }
                }
            } catch (Error e) {
                warning (e.message);
            }

            return distro_name;
        }

        public static bool is_kde () {
            string[] desktop_identifiers = {
                Environment.get_variable ("XDG_CURRENT_DESKTOP") ?? "",
                Environment.get_variable ("XDG_SESSION_DESKTOP") ?? "",
                Environment.get_variable ("DESKTOP_SESSION") ?? ""
            };

            foreach (var identifier in desktop_identifiers) {
                var desktop = identifier.ascii_down ();

                if (desktop.contains ("kde") || desktop.contains ("plasma"))
                    return true;
            }

            return false;
        }

        public static void open_uri (string uri) {
            AppInfo.launch_default_for_uri_async.begin (uri, null, null, (obj, res) => {
                try {
                    AppInfo.launch_default_for_uri_async.end (res);
                } catch (Error error) {
                    GLib.warning (error.message);
                }
            });
        }

        public static string file_uri_for_path (string path) {
            return File.new_for_path (path).get_uri ();
        }

        public static void open_path (string path) {
            open_uri (file_uri_for_path (path));
        }

        public static void systemd_handler () {
            systemd_update_pending = true;
            if (systemd_update_running)
                return;

            systemd_update_running = true;
            update_systemd_files.begin ();
        }

        private static async void update_systemd_files () {
            do {
                systemd_update_pending = false;
                var manager = get_systemd_timer_manager ();
                if (manager != null) {
                    yield ((!) manager).reconcile (
                        Globals.SETTINGS.get_boolean ("check-updates-on-boot"),
                        Globals.SETTINGS.get_boolean ("background-updates"),
                        Globals.SETTINGS.get_enum ("background-updates-frequency")
                    );
                }
            } while (systemd_update_pending);

            systemd_update_running = false;
        }

        private static SystemdTimerManager? get_systemd_timer_manager () {
            if (systemd_timer_manager != null)
                return systemd_timer_manager;

            string executable = Globals.IS_FLATPAK ?
                "/usr/bin/flatpak run com.vysp3r.ProtonPlus" :
                Environment.find_program_in_path ("protonplus") ?? "protonplus";
            string exec_start = "%s update all".printf (executable);

            try {
                var service_resource = resources_lookup_data ("/com/vysp3r/ProtonPlus/protonplus.service", ResourceLookupFlags.NONE);
                var timer_resource = resources_lookup_data ("/com/vysp3r/ProtonPlus/protonplus.timer", ResourceLookupFlags.NONE);
                systemd_timer_manager = new SystemdTimerManager (
                    new HostSystemctlBackend (),
                    Path.build_filename (Environment.get_user_config_dir (), "systemd", "user"),
                    Parser.data_to_string (service_resource.get_data ()),
                    Parser.data_to_string (timer_resource.get_data ()),
                    exec_start
                );
            } catch (Error e) {
                warning (e.message);
                return null;
            }

            return systemd_timer_manager;
        }
    }
}
