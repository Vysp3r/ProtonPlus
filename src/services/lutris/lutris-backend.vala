namespace ProtonPlus.Services {
    [Flags]
    public enum LutrisSystemTools {
        UNKNOWN = 0,
        CHECKED = 1,
        MANGOHUD = 2,
        GAMEMODE = 4,
        GAMESCOPE = 8
    }

    public interface LutrisBackend : Object {
        public abstract bool is_closed (bool flatpak) throws Error;
        public abstract Gee.List<Models.CompatibilityTool> get_runners (bool flatpak, string? custom_path) throws Error;
        public abstract Subprocess? spawn (string[] argv) throws Error;
        public virtual LutrisSystemTools get_system_tools (bool flatpak) throws Error {
            return LutrisSystemTools.UNKNOWN;
        }
    }

    public class HostLutrisBackend : Object, LutrisBackend {
        internal const string APP_ID = "net.lutris.Lutris";
        // Run the resolver in Lutris's own environment without starting its
        // application or asking it to initialize or migrate the library.
        private const string RUNNER_PROBE = """
import json, os, shutil, sys, tempfile

# Lutris opens a logfile while importing its settings.
cache = tempfile.TemporaryDirectory(prefix="protonplus-lutris-", dir="/tmp")
os.environ["XDG_CACHE_HOME"] = cache.name

launcher = shutil.which("lutris")
if launcher:
    sys.argv[0] = launcher
    base = os.path.dirname(os.path.realpath(launcher))
    for root in reversed((os.path.join(base, ".."), os.path.join(base, "../lib/lutris"))):
        if os.path.isfile(os.path.join(root, "lutris/__init__.py")):
            sys.path.insert(0, root)

if len(sys.argv) > 2 and sys.argv[2] == "--system-tools":
    from lutris.util import linux, system

    print(1 + 2 * int(bool(system.can_find_executable("mangohud"))) +
          4 * int(bool(linux.LINUX_SYSTEM.gamemode_available())) +
          8 * int(bool(system.can_find_executable("gamescope"))))
    sys.exit(0)

from lutris import settings
from lutris.exceptions import MissingExecutableError
from lutris.util.wine import wine, proton

def executable(path):
    return bool(path and os.path.isfile(path) and os.access(path, os.X_OK))

try:
    umu = proton.get_umu_path()
except MissingExecutableError:
    umu = None
has_umu = executable(umu)
find_proton = getattr(proton, "find_proton_version", None)
latest = wine.get_default_wine_version()
protons = proton.get_proton_versions() if has_umu else {}
if not has_umu:
    # Lutris omits these builds from the picker without umu. Retain their
    # paths for saved IDs and removal dependency checks.
    for root in proton._iter_proton_locations():
        try:
            for version in os.listdir(root):
                path = os.path.join(root, version)
                if os.path.isfile(os.path.join(path, "proton")):
                    protons.setdefault(version, path)
        except FileNotFoundError:
            pass

aliases = {}
if find_proton:
    arch = proton.LINUX_SYSTEM.arch
    for version in protons:
        if version.endswith("-" + arch):
            tag = version[:-(len(arch) + 1)]
            if proton.is_ge_proton_release(tag) and tag not in protons:
                aliases[tag] = version

def row(version, path, kind, assignable, status="", root=""):
    return [version, path or "", kind, assignable, status, os.path.realpath(root) if root else ""]

versions = set(wine.list_lutris_wine_versions()) | set(wine.WINE_PATHS) | set(protons) | set(aliases)
versions.difference_update({"custom", latest})
result = [row(latest, "", True, bool(find_proton), "" if has_umu else "umu")]
for version in sorted(versions):
    name = aliases.get(version, version)
    if name in protons and version not in wine.WINE_PATHS:
        root = protons[name]
        path = ""
        if has_umu:
            try:
                path = wine.get_wine_path_for_version(version)
            except MissingExecutableError:
                pass
        status = "umu" if not has_umu else (
            "" if executable(path) and executable(os.path.join(root, "proton")) else "missing")
        result.append(row(version, path, True, True, status, root))
    else:
        try:
            path = wine.get_wine_path_for_version(version)
        except MissingExecutableError:
            continue
        if executable(path):
            root = "" if version in wine.WINE_PATHS else os.path.join(settings.WINE_DIR, version)
            result.append(row(version, path, False, True, root=root))

custom = sys.argv[1]
if os.path.isabs(custom) and executable(custom):
    real = os.path.realpath(custom)
    root = next((path for path in protons.values()
                 if real.startswith(os.path.realpath(path) + os.sep)), "")
    is_proton = bool(root) or proton.is_umu_path(custom)
    result.append(row("custom", custom, is_proton, False,
                      "umu" if is_proton and not has_umu else "", root))
print(json.dumps(result))
""";

        private const string NATIVE_PROCESS_PROBE = """
import os, sys

for pid in os.listdir("/proc"):
    if not pid.isdecimal() or pid == str(os.getpid()):
        continue
    root = "/proc/" + pid
    try:
        if os.stat(root).st_uid != os.getuid():
            continue
        with open(root + "/cmdline", "rb") as f:
            args = f.read().split(b"\0")
        with open(root + "/comm", "rb") as f:
            comm = f.read().strip()
        if not args or not args[0]:
            continue
        first = os.path.basename(args[0])
        launcher = {b"lutris", b"lutris-wrapper", b"net.lutris.Lutris"}
        script = first.startswith(b"python") and len(args) > 1 and os.path.basename(args[1]) in launcher
        if first not in launcher and comm not in launcher and not script:
            continue
        with open(root + "/cgroup", "rb") as f:
            if b"app-flatpak-net.lutris.Lutris" in f.read():
                continue
        with open(root + "/environ", "rb") as f:
            if b"FLATPAK_ID=net.lutris.Lutris" not in f.read().split(b"\0"):
                print("running")
                sys.exit(0)
    except (FileNotFoundError, ProcessLookupError):
        continue
print("closed")
""";

        private string? data_home;
        private string? config_home;
        private bool through_host;

        public HostLutrisBackend (string? data_home = null, string? config_home = null, bool through_host = false) {
            this.data_home = data_home;
            this.config_home = config_home;
            this.through_host = through_host;
        }

        public static string[] on_host (string[] argv, bool through_host) {
            if (!through_host)
                return argv;
            return prepend ({ "flatpak-spawn", "--host" }, argv);
        }

        private static string[] prepend (string[] head, string[] tail) {
            var command = head;
            foreach (var argument in tail)
                command += argument;
            return command;
        }

        private static string query (string[] argv) throws Error {
            return Utils.System.query_process (argv, _("Could not query the selected Lutris installation."));
        }

        internal static void read_flatpak_profile_homes (bool through_host, string home,
            out string? data_home, out string? config_home) {
            data_home = null;
            config_home = null;
            if (!through_host && Environment.find_program_in_path ("flatpak") == null)
                return;
            try {
                // Includes per-app and global Flatpak overrides without
                // launching Lutris or creating its application sandbox.
                var permissions = query (on_host ({ "flatpak", "info", "--show-permissions", APP_ID }, through_host));
                var metadata = new KeyFile ();
                metadata.load_from_data (permissions, permissions.length, KeyFileFlags.NONE);
                data_home = flatpak_xdg_home (metadata, "XDG_DATA_HOME", Path.build_filename (home, ".local", "share"));
                config_home = flatpak_xdg_home (metadata, "XDG_CONFIG_HOME", Path.build_filename (home, ".config"));
            } catch (Error error) {
                debug ("Could not read Lutris Flatpak metadata: %s", error.message);
            }
        }

        private static string? flatpak_xdg_home (KeyFile metadata, string variable, string glib_default) throws Error {
            if (!metadata.has_group ("Environment") || !metadata.has_key ("Environment", variable))
                return null;
            var value = metadata.get_string ("Environment", variable);
            return Path.is_absolute (value) ? value : glib_default;
        }

        public bool is_closed (bool flatpak) throws Error {
            if (!flatpak) {
                string[] command = { "sh", "-c",
                    "if command -v python3 >/dev/null; then exec python3 -I -B -c \"$1\"; " +
                    "elif command -v lutris >/dev/null; then exit 1; else echo closed; fi",
                    "lutris-process-check", NATIVE_PROCESS_PROBE };
                var native_state = query (on_host (command, Globals.IS_FLATPAK));
                return native_state.strip () == "closed";
            }
            if (!Globals.IS_FLATPAK && Environment.find_program_in_path ("flatpak") == null)
                return true;
            return Utils.System.is_flatpak_launcher_closed (APP_ID,
                _("Could not query the selected Lutris installation."));
        }

        private static string[] runner_probe_command (bool flatpak, string? custom_path, bool through_host,
            string? data_home = null, string? config_home = null, bool system_tools = false) {
            string[] argv = { "python3", "-I", "-B", "-c", RUNNER_PROBE, custom_path ?? "" };
            if (system_tools)
                argv += "--system-tools";
            if (flatpak)
                argv = prepend ({ "flatpak", "run", "--command=python3", Utils.System.FLATPAK_RUNNER_PROBE_OPTION,
                    APP_ID }, argv[1:argv.length]);
            else if (data_home != null && config_home != null)
                argv = prepend ({ "env", "XDG_DATA_HOME=" + data_home, "XDG_CONFIG_HOME=" + config_home }, argv);
            return on_host (argv, through_host);
        }

        public Gee.List<Models.CompatibilityTool> get_runners (bool flatpak, string? custom_path) throws Error {
            var argv = runner_probe_command (flatpak, custom_path, through_host, data_home, config_home);
            return parse_runner_probe (query_runner_probe (argv));
        }

        public LutrisSystemTools get_system_tools (bool flatpak) throws Error {
            var argv = runner_probe_command (flatpak, null, through_host, data_home, config_home, true);
            int tools;
            if (!int.try_parse (query_runner_probe (argv).strip (), out tools) || tools < 1 || tools > 15 ||
                (tools & (int) LutrisSystemTools.CHECKED) == 0)
                throw new IOError.INVALID_DATA (_("Could not query the selected Lutris installation."));
            return (LutrisSystemTools) tools;
        }

        protected virtual string query_runner_probe (string[] argv) throws Error {
            return query (argv);
        }

        private static Gee.List<Models.CompatibilityTool> parse_runner_probe (string output) throws Error {
            var parser = new Json.Parser ();
            parser.load_from_data (output);
            if (parser.get_root () == null || parser.get_root ().get_node_type () != Json.NodeType.ARRAY)
                throw new IOError.INVALID_DATA (_("Could not query the selected Lutris installation."));
            var result = new Gee.ArrayList<Models.CompatibilityTool> ();
            foreach (var entry in parser.get_root ().get_array ().get_elements ()) {
                if (entry.get_node_type () != Json.NodeType.ARRAY || entry.get_array ().get_length () != 6)
                    throw new IOError.INVALID_DATA (_("Could not query the selected Lutris installation."));
                var row = entry.get_array ();
                var id = row.get_string_element (0);
                if (id == "" || id == "Default")
                    continue;
                var path = row.get_string_element (1);
                var kind = row.get_boolean_element (2)
                    ? Models.CompatibilityToolRuntimeKind.PROTON : Models.CompatibilityToolRuntimeKind.WINE;
                var title = id == "ge-proton" && path == "" ? _("GE-Proton (Latest)") : id;
                var status = row.get_string_element (4);
                var diagnostic = status == "umu" ? _("umu is required") :
                    status == "missing" ? _("Runner is missing") : null;
                result.add (new Models.CompatibilityTool (title, id, path, kind) {
                    is_assignable = row.get_boolean_element (3),
                    is_available = diagnostic == null,
                    availability_diagnostic = diagnostic,
                    installation_path = row.get_string_element (5)
                });
            }
            return result;
        }

        public Subprocess? spawn (string[] argv) throws Error {
            return Utils.System.spawn_detached (argv);
        }
    }
}
