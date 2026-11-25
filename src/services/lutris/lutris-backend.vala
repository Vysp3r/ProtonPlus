namespace ProtonPlus.Services {
    public interface LutrisBackend : Object {
        public abstract bool is_closed (bool flatpak) throws Error;
        public abstract Gee.List<Models.CompatibilityTool> get_runners (bool flatpak, string? custom_path) throws Error;
        public abstract Subprocess? spawn (string[] argv) throws Error;
    }

    public class HostLutrisBackend : Object, LutrisBackend {
        internal const string APP_ID = "net.lutris.Lutris";
        // Run the resolver in Lutris's own environment without starting its
        // application or asking it to initialize or migrate the library.
        private const string RUNNER_PROBE = """
import json, os, shutil, sys

launcher = shutil.which("lutris")
if launcher:
    sys.argv[0] = launcher
    base = os.path.dirname(os.path.realpath(launcher))
    for root in reversed((os.path.join(base, ".."), os.path.join(base, "../lib/lutris"))):
        if os.path.isfile(os.path.join(root, "lutris/__init__.py")):
            sys.path.insert(0, root)

from lutris.util.wine import wine, proton

def executable(path):
    return path and os.path.isfile(path) and os.access(path, os.X_OK)

protons = proton.get_proton_versions()
latest = getattr(wine, "GE_PROTON_LATEST", "")
versions = set(wine.list_lutris_wine_versions()) | set(wine.WINE_PATHS) | set(protons)
versions.discard("custom")
versions.discard(latest)
result = []
for version in sorted(versions):
    try:
        path = wine.get_wine_path_for_version(version)
    except Exception:
        continue
    is_proton = version in protons and version not in wine.WINE_PATHS
    if executable(path) and (not is_proton or executable(os.path.join(protons[version], "proton"))):
        result.append([version, path, is_proton, True])

if latest:
    try:
        if executable(proton.get_umu_path()):
            # The latest ID is a fallback on these releases, so display it
            # when present in a config without offering it as an override.
            result.append([latest, "", True, False])
    except Exception:
        pass

custom = sys.argv[1]
if os.path.isabs(custom) and executable(custom):
    is_proton = proton.is_proton_path(custom) or proton.is_umu_path(custom)
    result.append(["custom", custom, is_proton, False])
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

        public Gee.List<Models.CompatibilityTool> get_runners (bool flatpak, string? custom_path) throws Error {
            string[] argv = { "python3", "-I", "-B", "-c", RUNNER_PROBE, custom_path ?? "" };
            if (flatpak)
                argv = prepend ({ "flatpak", "run", "--command=python3", Utils.System.FLATPAK_RUNNER_PROBE_OPTION,
                    APP_ID }, argv[1:argv.length]);
            var output = query (on_host (argv, Globals.IS_FLATPAK));
            var parser = new Json.Parser ();
            parser.load_from_data (output);
            if (parser.get_root () == null || parser.get_root ().get_node_type () != Json.NodeType.ARRAY)
                throw new IOError.INVALID_DATA (_("Could not query the selected Lutris installation."));
            var result = new Gee.ArrayList<Models.CompatibilityTool> ();
            foreach (var entry in parser.get_root ().get_array ().get_elements ()) {
                if (entry.get_node_type () != Json.NodeType.ARRAY || entry.get_array ().get_length () != 4)
                    throw new IOError.INVALID_DATA (_("Could not query the selected Lutris installation."));
                var row = entry.get_array ();
                var id = row.get_string_element (0);
                if (id == "" || id == "Default")
                    continue;
                var path = row.get_string_element (1);
                var kind = row.get_boolean_element (2)
                    ? Models.CompatibilityToolRuntimeKind.PROTON : Models.CompatibilityToolRuntimeKind.WINE;
                var title = id == "ge-proton" && path == "" ? _("GE-Proton (Latest)") : id;
                result.add (new Models.CompatibilityTool (title, id, path, kind) {
                    is_assignable = row.get_boolean_element (3)
                });
            }
            return result;
        }

        public Subprocess? spawn (string[] argv) throws Error {
            return Utils.System.spawn_detached (argv);
        }
    }
}
