namespace ProtonPlus.Services {
    public interface FaugusBackend : Object {
        public abstract bool is_closed (bool flatpak) throws Error;
        public abstract bool host_path_exists (string path) throws Error;
        public abstract Gee.List<Models.CompatibilityTool> installed_runners (bool flatpak) throws Error;
        public abstract Subprocess? spawn (string[] argv, string working_directory) throws Error;
    }

    public class HostFaugusBackend : Object, FaugusBackend {
        private const string NATIVE_PROCESS_PROBE = """
import os
from pathlib import Path

app_id = b"io.github.Faugus.faugus-launcher"
scripts = {b"faugus-launcher", b"faugus-run", b"faugus_launcher.py",
           b"faugus_run.py", b"faugus-shortcut", b"faugus-proton-manager"}
modules = {b"faugus.launcher", b"faugus.runner", b"faugus.tray_only",
           b"faugus.shortcut", b"faugus.ea_fix", b"faugus.backup",
           b"faugus.proton_manager"}

for root in Path("/proc").iterdir():
    if not root.name.isdecimal():
        continue
    try:
        if root.stat().st_uid != os.getuid():
            continue
        argv = (root / "cmdline").read_bytes().split(b"\0")
        command = os.path.basename(argv[0])
        script = len(argv) > 1 and os.path.basename(argv[1]) in scripts
        module = len(argv) > 2 and argv[1] == b"-m" and argv[2] in modules
        if command not in scripts and not (module or script):
            continue
        if b"FLATPAK_ID=" + app_id in (root / "environ").read_bytes().split(b"\0"):
            continue
        if app_id in (root / "cgroup").read_bytes():
            continue
        print("running")
        break
    except (FileNotFoundError, ProcessLookupError):
        continue
else:
    print("closed")
""";

        // Probe in the selected launcher's environment. Importing path_manager
        // would migrate Faugus files, so mirror the read-only discovery rules.
        private const string RUNNER_PROBE = """
import json, os
from pathlib import Path

home = Path.home()
host_home = Path(os.environ.get("HOST_HOME", home)) if "FLATPAK_ID" in os.environ else home
host_data = Path(os.environ.get("HOST_XDG_DATA_HOME", home / ".local/share"))
native = host_data / "Steam/compatibilitytools.d"
flatpak = host_home / ".var/app/com.valvesoftware.Steam/.local/share/Steam/compatibilitytools.d"
reserved = {"UMU-Latest", "LegacyRuntime", "Proton-GE Latest", "DW-Proton Latest",
            "Proton-CachyOS Latest", "Proton-Wineland Latest"}
versions = {}
roots = [native, flatpak] if native != flatpak else [native]
for root in roots:
    try:
        for entry in root.iterdir():
            if not entry.is_dir():
                continue
            if entry.name in reserved:
                if root != native:
                    versions[str(entry)] = [entry.name, str(entry), True]
            else:
                versions.setdefault(entry.name, [entry.name, str(entry), root != native])
    except (FileNotFoundError, PermissionError, NotADirectoryError):
        continue

for directory in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
    path = Path(directory) / "steam/compatibilitytools.d/proton-cachyos-slr"
    if path.exists():
        versions["Proton-CachyOS (System)"] = ["Proton-CachyOS (System)", str(path), False]
        break
print(json.dumps([[key, *value] for key, value in versions.items()]))
""";

        public static string[] on_host (string[] argv, bool through_host) {
            if (!through_host)
                return argv;
            string[] command = { "flatpak-spawn", "--host" };
            foreach (var argument in argv)
                command += argument;
            return command;
        }

        private static string query (string[] argv) throws Error {
            return Utils.System.query_process (on_host (argv, Globals.IS_FLATPAK),
                _("Could not query the selected Faugus installation."));
        }

        public bool is_closed (bool flatpak) throws Error {
            if (!flatpak)
                return query ({ "python3", "-I", "-B", "-c", NATIVE_PROCESS_PROBE }).strip () == "closed";
            return Utils.System.is_flatpak_launcher_closed (Models.Launchers.FaugusLauncher.FLATPAK_ID,
                _("Could not query the selected Faugus installation."));
        }

        public bool host_path_exists (string path) throws Error {
            return query ({ "python3", "-I", "-B", "-c", """
import os, sys
try:
    os.lstat(sys.argv[1])
    print("present")
except FileNotFoundError:
    print("missing")
""", path }).strip () == "present";
        }

        public Gee.List<Models.CompatibilityTool> installed_runners (bool flatpak) throws Error {
            var output = flatpak
                ? query ({ "flatpak", "run", "--command=python3", Utils.System.FLATPAK_RUNNER_PROBE_OPTION,
                    Models.Launchers.FaugusLauncher.FLATPAK_ID, "-I", "-B", "-c", RUNNER_PROBE })
                : query ({ "python3", "-I", "-B", "-c", RUNNER_PROBE });
            var parser = new Json.Parser ();
            parser.load_from_data (output);
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.ARRAY)
                throw new IOError.INVALID_DATA (_("Could not query the selected Faugus installation."));
            var result = new Gee.ArrayList<Models.CompatibilityTool> ();
            foreach (var entry in root.get_array ().get_elements ()) {
                var row = entry.get_array ();
                var id = row.get_string_element (0);
                var title = row.get_string_element (1);
                if (row.get_boolean_element (3))
                    title = _("%s (Flatpak)").printf (title);
                result.add (new Models.CompatibilityTool (title, id, row.get_string_element (2),
                    Models.CompatibilityToolRuntimeKind.PROTON));
            }
            return result;
        }

        public Subprocess? spawn (string[] argv, string working_directory) throws Error {
            return Utils.System.spawn_detached (argv, working_directory);
        }
    }
}
