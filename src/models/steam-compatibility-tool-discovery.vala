namespace ProtonPlus.Models {
    /* Discovers tools Steam may select without granting ProtonPlus ownership
     * of their files or installation lifecycle. Roots are constructor-
     * injectable so tests never inspect real Steam, /usr, or Flatpak data. */
    public class SteamCompatibilityToolDiscovery : Object {
        private Launcher.InstallationTypes installation_type;
        private string system_root;
        private string system_inspection_root;
        private string[] flatpak_runtime_roots;
        private Gee.HashMap<string, CompatibilityTool> tools_by_internal_title;
        private Gee.HashMap<string, int> precedence_by_internal_title;
        private Gee.HashMap<string, string> internal_title_by_logical_location;
        private Gee.HashMap<string, uint> steam_appid_by_internal_title;

        public SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes installation_type,
            bool running_in_flatpak = false,
            string system_root = "/usr/share/steam/compatibilitytools.d",
            string system_inspection_root = "",
            string[]? flatpak_runtime_roots = null
        ) {
            this.installation_type = installation_type;
            this.system_root = system_root;
            this.system_inspection_root = system_inspection_root != ""
                ? system_inspection_root
                : running_in_flatpak
                    ? "/run/host/usr/share/steam/compatibilitytools.d"
                    : system_root;
            if (flatpak_runtime_roots != null) {
                this.flatpak_runtime_roots = (!) flatpak_runtime_roots;
            } else {
                this.flatpak_runtime_roots = {
                    Path.build_filename (Environment.get_home_dir (), ".local", "share", "flatpak", "runtime"),
                    "/var/lib/flatpak/runtime"
                };
            }
            tools_by_internal_title = new Gee.HashMap<string, CompatibilityTool> ();
            precedence_by_internal_title = new Gee.HashMap<string, int> ();
            internal_title_by_logical_location = new Gee.HashMap<string, string> ();
            steam_appid_by_internal_title = new Gee.HashMap<string, uint> ();
        }

        public void clear () {
            tools_by_internal_title.clear ();
            precedence_by_internal_title.clear ();
            internal_title_by_logical_location.clear ();
            steam_appid_by_internal_title.clear ();
        }

        public void add_steam_library_app (
            string path,
            uint appid,
            string internal_title,
            string display_title,
            CompatibilityToolRuntimeKind runtime_kind
        ) {
            var tool = new CompatibilityTool (
                display_title, internal_title, path, runtime_kind, path, true
            );
            if (!steam_library_tool_is_usable (tool, appid))
                return;
            add_tool (tool, 300, appid);
        }

        public static bool try_get_steam_library_tool_identity (
            uint appid,
            out string internal_title,
            out CompatibilityToolRuntimeKind runtime_kind
        ) {
            runtime_kind = CompatibilityToolRuntimeKind.PROTON;
            switch (appid) {
            case 2180100: internal_title = "proton_hotfix"; return true;
            case 1493710: internal_title = "proton_experimental"; return true;
            case 3658110: internal_title = "proton_10"; return true;
            case 4628710: internal_title = "proton_11"; return true;
            case 2348590: internal_title = "proton_8"; return true;
            case 2805730: internal_title = "proton_9"; return true;
            case 1887720: internal_title = "proton_7"; return true;
            case 1580130: internal_title = "proton_63"; return true;
            case 1420170: internal_title = "proton_513"; return true;
            case 1245040: internal_title = "proton_5"; return true;
            case 1054830: internal_title = "proton_411"; return true;
            case 1113280: internal_title = "proton_42"; return true;
            case 961940: internal_title = "proton_316"; return true;
            case 858280: internal_title = "proton_37"; return true;
            case 1070560:
                internal_title = "steamlinuxruntime";
                runtime_kind = CompatibilityToolRuntimeKind.NATIVE;
                return true;
            case 1391110:
                internal_title = "steamlinuxruntime_soldier";
                runtime_kind = CompatibilityToolRuntimeKind.NATIVE;
                return true;
            case 1628350:
                internal_title = "steamlinuxruntime_sniper";
                runtime_kind = CompatibilityToolRuntimeKind.NATIVE;
                return true;
            case 4183110:
                internal_title = "steamlinuxruntime_4";
                runtime_kind = CompatibilityToolRuntimeKind.NATIVE;
                return true;
            default:
                internal_title = "";
                runtime_kind = CompatibilityToolRuntimeKind.UNKNOWN;
                return false;
            }
        }

        public void discover_launcher_roots (string managed_tools_root) {
            discover_children (managed_tools_root, managed_tools_root, false, 100);

            if (installation_type == Launcher.InstallationTypes.SYSTEM) {
                discover_children (system_root, system_inspection_root, true, 200);
            } else if (installation_type == Launcher.InstallationTypes.FLATPAK) {
                discover_flatpak_extensions ();
            }
        }

        public Gee.List<CompatibilityTool> get_snapshot () {
            var snapshot = new Gee.ArrayList<CompatibilityTool> ();
            foreach (var tool in tools_by_internal_title.values)
                snapshot.add (tool);
            return snapshot;
        }

        public bool remains_available (CompatibilityTool tool) {
            if (!tool.is_available || tool.inspection_path.strip () == "")
                return false;
            var steam_appid = steam_appid_by_internal_title.get (tool.internal_title);
            if (steam_appid != 0)
                return steam_library_tool_is_usable (tool, steam_appid);
            var current = ProtonPlus.Utils.VDF.CompatibilityToolLoader.try_from_paths (
                tool.path, tool.inspection_path, tool.externally_managed
            );
            return current != null && ((!) current).internal_title == tool.internal_title;
        }

        private void discover_flatpak_extensions () {
            foreach (var runtime_root in flatpak_runtime_roots) {
                foreach_directory_child (runtime_root, (extension_id, extension_root) => {
                    if (!(extension_id.has_prefix ("com.valvesoftware.Steam.CompatibilityTool.")
                        || extension_id.has_prefix ("com.valvesoftware.Steam.Utility.")))
                        return;
                    foreach_directory_child (extension_root, (arch, arch_root) => {
                        foreach_directory_child (arch_root, (branch, branch_root) => {
                            var active_deployment = get_active_deployment_name (branch_root);
                            foreach_directory_child (branch_root, (deployment, deployment_root) => {
                                if (deployment == "active")
                                    return;
                                var precedence = deployment == active_deployment ? 150 : 250;
                                var files_root = Path.build_filename (deployment_root, "files");
                                if (!is_directory_without_following (files_root))
                                    return;
                                add_tool_path (files_root, files_root, true, precedence);
                                var tools_root = Path.build_filename (
                                    files_root, "share", "steam", "compatibilitytools.d"
                                );
                                discover_children (tools_root, tools_root, true, precedence);
                            });
                        });
                    });
                });
            }
        }

        private delegate void DirectoryChildCallback (string name, string path);

        private void foreach_directory_child (string root, DirectoryChildCallback callback) {
            if (!is_directory_without_following (root))
                return;
            FileEnumerator? enumerator = null;
            try {
                var names = new Gee.ArrayList<string> ();
                enumerator = File.new_for_path (root).enumerate_children (
                    "standard::name,standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null
                );
                FileInfo? info;
                while ((info = enumerator.next_file ()) != null) {
                    if (info.get_file_type () != FileType.DIRECTORY)
                        continue;
                    var child = Path.build_filename (root, info.get_name ());
                    if (!is_directory_without_following (child))
                        continue;
                    names.add (info.get_name ());
                }
                names.sort ((a, b) => strcmp (a, b));
                foreach (var name in names)
                    callback (name, Path.build_filename (root, name));
            } catch (Error error) {
                debug ("Compatibility-tool root %s is unavailable: %s", root, error.message);
            } finally {
                if (enumerator != null) {
                    try { ((!) enumerator).close (null); } catch (Error error) {}
                }
            }
        }

        /* Flatpak's active entry is a symlink. Read only its target name, then
         * inspect the independently lstat-validated deployment directory; do
         * not enumerate through or resolve the symlink itself. */
        private string get_active_deployment_name (string branch_root) {
            try {
                var info = File.new_for_path (Path.build_filename (branch_root, "active")).query_info (
                    "standard::type,standard::symlink-target",
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null
                );
                if (info.get_file_type () != FileType.SYMBOLIC_LINK)
                    return "";
                var target = info.get_symlink_target ();
                if (target == null || target == "" || Path.is_absolute ((!) target)
                    || ((!) target).contains ("/") || (!) target == "." || (!) target == "..")
                    return "";
                return (!) target;
            } catch (Error error) {
                return "";
            }
        }

        private void discover_children (
            string path_root,
            string inspection_root,
            bool externally_managed,
            int precedence
        ) {
            foreach_directory_child (inspection_root, (name, inspection_path) => {
                add_tool_path (
                    Path.build_filename (path_root, name), inspection_path,
                    externally_managed, precedence
                );
            });
        }

        private void add_tool_path (
            string path,
            string inspection_path,
            bool externally_managed,
            int precedence,
            CompatibilityToolRuntimeKind runtime_kind = CompatibilityToolRuntimeKind.UNKNOWN
        ) {
            var tool = ProtonPlus.Utils.VDF.CompatibilityToolLoader.try_from_paths (
                path, inspection_path, externally_managed
            );
            if (tool == null)
                return;
            if (runtime_kind != CompatibilityToolRuntimeKind.UNKNOWN)
                ((!) tool).runtime_kind = runtime_kind;

            add_tool ((!) tool, precedence);
        }

        private void add_tool (CompatibilityTool tool, int precedence, uint steam_appid = 0) {
            var logical_location = normalize_logical_location (tool.path);
            var location_internal_title = internal_title_by_logical_location.get (logical_location);
            if (location_internal_title != null) {
                var location_precedence = precedence_by_internal_title.get ((!) location_internal_title);
                if (location_precedence <= precedence)
                    return;
                remove_tool ((!) location_internal_title);
            }
            var existing_precedence = precedence_by_internal_title.get (tool.internal_title);
            if (tools_by_internal_title.has_key (tool.internal_title)
                && existing_precedence <= precedence)
                return;

            if (tools_by_internal_title.has_key (tool.internal_title))
                remove_tool (tool.internal_title);
            tools_by_internal_title.set (tool.internal_title, tool);
            precedence_by_internal_title.set (tool.internal_title, precedence);
            internal_title_by_logical_location.set (logical_location, tool.internal_title);
            if (steam_appid != 0)
                steam_appid_by_internal_title.set (tool.internal_title, steam_appid);
        }

        private void remove_tool (string internal_title) {
            var existing = tools_by_internal_title.get (internal_title);
            if (existing != null)
                internal_title_by_logical_location.unset (
                    normalize_logical_location (((!) existing).path)
                );
            tools_by_internal_title.unset (internal_title);
            precedence_by_internal_title.unset (internal_title);
            steam_appid_by_internal_title.unset (internal_title);
        }

        private bool steam_library_tool_is_usable (CompatibilityTool tool, uint appid) {
            string expected_internal_title;
            CompatibilityToolRuntimeKind expected_runtime_kind;
            if (!try_get_steam_library_tool_identity (
                    appid, out expected_internal_title, out expected_runtime_kind
                )
                || expected_internal_title != tool.internal_title
                || expected_runtime_kind != tool.runtime_kind
                || !is_directory_without_following (tool.inspection_path))
                return false;

            Posix.Stat manifest_stat;
            if (Posix.lstat (
                    Path.build_filename (tool.inspection_path, "toolmanifest.vdf"),
                    out manifest_stat
                ) != 0 || !Posix.S_ISREG (manifest_stat.st_mode))
                return false;
            if (expected_runtime_kind != CompatibilityToolRuntimeKind.PROTON)
                return true;

            Posix.Stat proton_stat;
            return Posix.lstat (
                Path.build_filename (tool.inspection_path, "proton"), out proton_stat
            ) == 0 && Posix.S_ISREG (proton_stat.st_mode);
        }

        private string normalize_logical_location (string path) {
            var canonical = Filename.canonicalize (path, null);
            if (canonical.has_prefix ("/run/host/"))
                return canonical.substring ("/run/host".length);
            return canonical;
        }

        private bool is_directory_without_following (string path) {
            Posix.Stat stat;
            return Posix.lstat (path, out stat) == 0 && Posix.S_ISDIR (stat.st_mode);
        }
    }
}
