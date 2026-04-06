namespace ProtonPlus.Utils {
    public class OptiScalerManager : Object {
        private static OptiScalerManager? _instance;
        public static OptiScalerManager instance {
            get {
                if (_instance == null) {
                    _instance = new OptiScalerManager();
                }
                return _instance;
            }
        }

        // Planned install options structure (expand later when UI implemented)
        public class InstallOptions : Object {
            public string injection_name { get; set; } // without .dll
            public bool disable_spoofing { get; set; }
            public bool use_bleeding_edge { get; set; }
            public bool apply_launch_override { get; set; }
            public bool preserve_ini { get; set; }

            public InstallOptions () {
                injection_name = "dxgi";
                disable_spoofing = false;
                use_bleeding_edge = true;
                apply_launch_override = true;
                preserve_ini = false;
            }
        }

        // Lightweight detection result
        public class State : Object {
            public bool installed { get; set; }
            public string? injection_file { get; set; }
            public string? version { get; set; }
            public bool conflict { get; set; } // true if OptiScaler.ini present but hash mismatch vs stored
            public string? exe_dir { get; set; }
        }

        // Persistent state entry (saved to JSON)
        private class StateEntry : Object {
            public string injection { get; set; }
            public string? version { get; set; }
            public string? hash { get; set; }
            public bool backup_created { get; set; }
            public string? original_launch_options { get; set; }
            public bool applied_override { get; set; }
            public string? exe_dir { get; set; }
            public Gee.ArrayList<string> installed_files { get; set; }

            public StateEntry () {
                installed_files = new Gee.ArrayList<string>();
            }
        }

        private Gee.HashMap<string,StateEntry> saved_state = new Gee.HashMap<string,StateEntry>();
        public string? last_error { get; private set; }

        private OptiScalerManager() {
            load_state();
        }

        // Tracks whether the last install operation created a backup (ephemeral – TODO: persist in state file later)
        private bool last_backup_created = false;

        // Detect whether OptiScaler appears installed for a given game (Steam only initially)
        public State detect(Models.Game game) {
            var state = new State();
            ProtonPlus.Models.Games.Steam? steam_game = game as ProtonPlus.Models.Games.Steam;
            if (steam_game == null) {
                state.installed = false; return state;
            }
            string base_dir = steam_game.installdir;
            if (base_dir == "") { state.installed = false; return state; }
            // If we have a saved exe_dir use it first
            var entry = saved_state.get("steam:" + steam_game.appid.to_string());
            Gee.List<string> dirs = new Gee.ArrayList<string>();
            if (entry != null && entry.exe_dir != null && entry.exe_dir.length > 0) dirs.add(entry.exe_dir);
            dirs.add(base_dir);
            string[] names = {"dxgi.dll", "winmm.dll", "d3d12.dll", "dbghelp.dll", "version.dll", "wininet.dll", "winhttp.dll"};
            foreach (var dir in dirs) {
                foreach (var name in names) {
                    var path = Path.build_filename(dir, name);
                    if (FileUtils.test(path, FileTest.IS_REGULAR)) {
                        var ini = Path.build_filename(dir, "OptiScaler.ini");
                        if (FileUtils.test(ini, FileTest.IS_REGULAR)) {
                            state.installed = true;
                            state.injection_file = name;
                            state.exe_dir = dir;
                        // Conflict check: compute hash & compare if stored
                            string? current_hash = compute_sha256(path);
                            if (entry != null && entry.hash != null && current_hash != null && entry.hash != current_hash) {
                                state.conflict = true;
                                state.version = entry.version; // keep stored version but flag conflict
                            } else {
                                if (entry != null) state.version = entry.version;
                            }
                            return state;
                        }
                    }
                }
            }
            state.installed = false;
            if (entry != null) state.exe_dir = entry.exe_dir; // preserve known exe_dir even if files missing
            return state;
        }

        // Minimal constants for Phase 1 (bleeding-edge bundle only)
        private const string BLEEDING_EDGE_REPO_API = "https://api.github.com/repos/xXJSONDeruloXx/OptiScaler-Bleeding-Edge/releases/latest";
        private const string CACHE_DIR_NAME = "optiscaler";
        private const string STATE_FILE_NAME = "state.json";

        private string get_cache_dir() {
            string base_dir = Environment.get_user_cache_dir();
            string dir = Path.build_filename(base_dir, Config.APP_NAME, CACHE_DIR_NAME);
            if (!FileUtils.test(dir, FileTest.IS_DIR)) {
                try { DirUtils.create(dir, 0755); } catch (Error e) { message(e.message); }
            }
            return dir;
        }

        private string? find_bundle_asset_url(string json) {
            try {
                var parser = new Json.Parser();
                parser.load_from_data(json, -1);
                var root = parser.get_root();
                if (root == null) return null;
                var obj = root.get_object();
                if (obj == null) return null;
                // capture release tag for later version recording
                if (obj.has_member("tag_name")) current_release_tag = obj.get_string_member("tag_name");
                if (!obj.has_member("assets")) return null;
                var assets = obj.get_array_member("assets");
                if (assets == null) return null;
                for (uint i = 0; i < assets.get_length(); i++) {
                    var asset = assets.get_object_element(i);
                    if (asset.has_member("browser_download_url")) {
                        string url = asset.get_string_member("browser_download_url");
                        if (url.index_of("BUNDLED_OptiScaler_") >= 0 && (url.has_suffix(".7z") || url.has_suffix(".zip"))) {
                            return url;
                        }
                    }
                }
            } catch (Error e) {
                message("OptiScaler JSON parse error: %s".printf(e.message));
            }
            return null;
        }

        private async string? download_bundle(string url) {
            string cache = get_cache_dir();
        // Derive filename from url tail
            string fname = "bundle.7z";
            int slash = url.last_index_of_char('/');
            if (slash >= 0 && slash + 1 < url.length) fname = url.substring(slash + 1);
            string path = Path.build_filename(cache, fname);
            bool ok = yield ProtonPlus.Utils.Web.Download(url, path);
            if (!ok) return null;
            return path;
        }

        private async string? extract_bundle(string archive_path) {
        // Reuse existing libarchive helper via Utils.Filesystem.extract expecting pattern (install_location + tool_name + extension)
        // For now, copy/rename into expected structure: we need tool_name + extension split.
            string dir = Path.get_dirname(archive_path);
            string base_name = Path.get_basename(archive_path); // e.g. BUNDLED_OptiScaler_xxx.7z
            string tool_name = base_name;
            string extension = "";
            int dot = base_name.last_index_of_char('.');
            if (dot > 0) {
                tool_name = base_name.substring(0, dot);
                extension = base_name.substring(dot); // includes .
            }
            // Utils.Filesystem.extract wants (install_location, tool_name, extension, cancel_cb)
            string install_location = dir + Path.DIR_SEPARATOR_S; // ensure trailing slash for concatenation inside extract
            string result = yield ProtonPlus.Utils.Filesystem.extract(install_location, tool_name, extension, () => { return false; });
            return result; // path to extracted top-level directory
        }

        private bool ensure_backup_if_needed(string game_dir, string injection_filename) {
            string target = Path.build_filename(game_dir, injection_filename);
            last_backup_created = false;
            if (!FileUtils.test(target, FileTest.IS_REGULAR)) {
                return true; // nothing to backup
            }
            // Heuristic: if OptiScaler.ini is present we assume it's already ours (update scenario) → skip backup
            string ini = Path.build_filename(game_dir, "OptiScaler.ini");
            if (FileUtils.test(ini, FileTest.IS_REGULAR)) {
                return true; // treat as ours
            }
            string backup = target + ".b";
            if (FileUtils.test(backup, FileTest.IS_REGULAR)) {
            // Backup already exists – assume previously created.
                return true;
            }
            // Attempt atomic rename to create backup.
            if (FileUtils.rename(target, backup) != 0) {
                message("OptiScaler: failed to create backup for %s".printf(target));
                return false; // fail to avoid overwriting foreign mod silently
            }
            last_backup_created = true; // TODO: persist this info in future state JSON
            return true;
        }

        private bool deploy_full(string extracted_root, string game_dir, string injection_name, bool preserve_ini, bool disable_spoofing, out string? deployed_hash, out Gee.ArrayList<string> installed_files) {
            installed_files = new Gee.ArrayList<string>();
        // Locate core files (may be inside a nested directory or use different casing)
            string core_dir;
            string dll_name;
            string ini_name;
            if (!find_core_dir(extracted_root, out core_dir, out dll_name, out ini_name)) {
                message("OptiScaler bundle missing core files");
                deployed_hash = null; return false;
            }
            string dll_source = Path.build_filename(core_dir, dll_name);
            string ini_source = Path.build_filename(core_dir, ini_name);
            string injection_filename = injection_name + ".dll";
            if (!ensure_backup_if_needed(game_dir, injection_filename)) {
                message("OptiScaler deploy aborted: backup failed for %s".printf(injection_filename));
                deployed_hash = null; return false;
            }
            // Core copy
            string dll_target = Path.build_filename(game_dir, injection_filename);
            string ini_target = Path.build_filename(game_dir, "OptiScaler.ini");
            try {
                copy_file_overwrite(dll_source, dll_target); installed_files.add(injection_filename);
                if (!preserve_ini || !FileUtils.test(ini_target, FileTest.IS_REGULAR)) {
                    copy_file_overwrite(ini_source, ini_target);
                }
                installed_files.add("OptiScaler.ini");
                // Supporting libraries & directories
                string[] support_files = {"amd_fidelityfx_dx12.dll","amd_fidelityfx_vk.dll","nvapi64.dll","nvngx.dll","amdxcffx64.dll","libxess.dll","libxess_dx11.dll","dlssg_to_fsr3_amd_is_better.dll","fakenvapi.ini"};
                foreach (var name in support_files) {
                    string src = Path.build_filename(extracted_root, name);
                    if (FileUtils.test(src, FileTest.IS_REGULAR)) {
                        string dst = Path.build_filename(game_dir, name);
                        copy_file_overwrite(src, dst);
                        installed_files.add(name);
                    }
                }
                string[] support_dirs = {"D3D12_Optiscaler","DlssOverrides"};
                foreach (var dname in support_dirs) {
                    string src_dir = Path.build_filename(extracted_root, dname);
                    if (FileUtils.test(src_dir, FileTest.IS_DIR)) {
                        string dst_dir = Path.build_filename(game_dir, dname);
                        copy_directory_recursive(src_dir, dst_dir, installed_files, game_dir);
                    }
                }
                if (disable_spoofing) {
                    apply_ini_spoof_toggle(ini_target, true);
                }
            } catch (Error e) {
                message(e.message);
                deployed_hash = null; return false;
            }
            deployed_hash = compute_sha256(dll_target);
            return true;
        }

        private void copy_file_overwrite(string src_path, string dst_path) throws Error {
            File src = File.new_for_path(src_path);
            File dst = File.new_for_path(dst_path);
            if (dst.query_exists()) dst.delete();
            src.copy(dst, FileCopyFlags.OVERWRITE);
        }

        private void copy_directory_recursive(string src_dir, string dst_dir, Gee.ArrayList<string> installed_files, string game_dir) throws Error {
            if (!FileUtils.test(dst_dir, FileTest.IS_DIR)) {
                DirUtils.create_with_parents(dst_dir, 0755);
            }
            Dir d = Dir.open(src_dir);
            string? name;
            while ((name = d.read_name()) != null) {
                string src_path = Path.build_filename(src_dir, name);
                string dst_path = Path.build_filename(dst_dir, name);
                if (FileUtils.test(src_path, FileTest.IS_DIR)) {
                    copy_directory_recursive(src_path, dst_path, installed_files, game_dir);
                } else if (FileUtils.test(src_path, FileTest.IS_REGULAR)) {
                    copy_file_overwrite(src_path, dst_path);
                // Record relative path under game_dir
                    if (dst_path.has_prefix(game_dir)) {
                        string rel = dst_path.substring(game_dir.length + (game_dir.has_suffix(Path.DIR_SEPARATOR_S) ? 0 : 1));
                        installed_files.add(rel);
                    }
                }
            }
            // Also record the top-level directory name itself (for removal convenience)
            if (dst_dir.has_prefix(game_dir)) {
                string rel_dir = dst_dir.substring(game_dir.length + (game_dir.has_suffix(Path.DIR_SEPARATOR_S) ? 0 : 1));
                if (!installed_files.contains(rel_dir)) installed_files.add(rel_dir);
            }
        }

        // Phase 1 minimal install: download bleeding-edge bundle & deploy core files. Returns true on success.
        private string? current_release_tag = null; // updated during find_bundle_asset_url
        public async bool install(Models.Game game, InstallOptions opts) throws Error {
            ProtonPlus.Models.Games.Steam? steam_game = game as ProtonPlus.Models.Games.Steam;
            if (steam_game == null) {
                message("OptiScaler install: non-Steam game unsupported in Phase 1");
                return false;
            }
            string base_dir = steam_game.installdir;
            if (base_dir == "") {
                message("OptiScaler install: empty game directory");
                return false;
            }
            // Determine executable dir (may differ for Unreal Shipping.exe)
            string game_dir = find_exe_dir(base_dir);
            // 1. Fetch latest bleeding-edge release JSON
            string json;
            var res = yield ProtonPlus.Utils.Web.get_request(BLEEDING_EDGE_REPO_API, Web.GetType.GITHUB, out json);
            if (res != ReturnCode.VALID_REQUEST) { message("Failed to fetch release info"); return false; }
            // 2. Find bundle asset URL
            string? asset_url = find_bundle_asset_url(json);
            if (asset_url == null) { message("No bundle asset found in release"); return false; }
            // 3. Download bundle
            string? archive_path = yield download_bundle(asset_url);
            if (archive_path == null) { message("Download failed"); return false; }
            // 4. Extract bundle
            string? extracted_root = yield extract_bundle(archive_path);
            if (extracted_root == null || extracted_root == "") { message("Extraction failed"); return false; }
            // 5. Determine actual root directory (libarchive wrapper returns first entry path which might be a file)
            string extracted_root_dir = extracted_root;
            if (!FileUtils.test(extracted_root_dir, FileTest.IS_DIR)) {
                extracted_root_dir = Path.get_dirname(extracted_root_dir);
            }
            message("OptiScaler: extracted root %s (normalized dir %s)".printf(extracted_root, extracted_root_dir));
            string? dll_hash; Gee.ArrayList<string> installed_files;
            if (!deploy_full(extracted_root_dir, game_dir, opts.injection_name, opts.preserve_ini, opts.disable_spoofing, out dll_hash, out installed_files)) {
                message("Deploy failed"); return false;
            }
            // Launch options override
            string? original_launch_options = null;
            bool applied_override = false;
            if (opts.apply_launch_override) {
                var steam_launcher = steam_game.launcher as ProtonPlus.Models.Launchers.Steam;
                if (steam_launcher != null) {
                    original_launch_options = steam_game.launch_options;
                    string merged = ProtonPlus.Utils.LaunchOptions.ensure_override(original_launch_options, opts.injection_name);
                    if (merged != original_launch_options) {
                        bool ok = steam_game.change_launch_options(merged, steam_launcher.profile.localconfig_path);
                        applied_override = ok && merged != original_launch_options;
                        if (!ok) {
                            last_error = _("Failed to update launch options");
                        }
                    }
                }
            }
            // Persist state
            var entry = new StateEntry();
            entry.injection = opts.injection_name + ".dll";
            // Version: prefer tag; else attempt derive from bundle filename
            string? version = current_release_tag;
            if (version != null && version.has_prefix("v")) version = version.substring(1); // strip leading v
            if (version == null && asset_url != null) {
            // crude parse: look for _v and next '_' or '.' sequence
                int vpos = asset_url.index_of("_v");
                if (vpos >= 0) {
                    int start = vpos + 2;
                    int end = start;
                    while (end < asset_url.length && (asset_url[end].isalnum() || asset_url[end] == '.' || asset_url[end] == '-' )) end++;
                    version = asset_url.substring(start, end);
                }
            }
            entry.version = version;
            entry.hash = dll_hash;
            entry.backup_created = last_backup_created;
            entry.original_launch_options = original_launch_options;
            entry.applied_override = applied_override;
            entry.exe_dir = game_dir;
            foreach (var f in installed_files) entry.installed_files.add(f);
            saved_state.set("steam:" + steam_game.appid.to_string(), entry);
            save_state();
            return true;
        }

        public async bool remove(Models.Game game) throws Error {
            ProtonPlus.Models.Games.Steam? steam_game = game as ProtonPlus.Models.Games.Steam;
            if (steam_game == null) {
                message("OptiScaler remove: non-Steam game unsupported in Phase 1");
                return false;
            }
            string base_dir = steam_game.installdir;
            if (base_dir == "") {
                message("OptiScaler remove: empty game directory");
                return false;
            }
            var key = "steam:" + steam_game.appid.to_string();
            StateEntry? stored = saved_state.get(key);
            string game_dir = (stored != null && stored.exe_dir != null && stored.exe_dir.length > 0) ? stored.exe_dir : base_dir;
            var state = detect(game);
            if (!state.installed || state.injection_file == null) {
            // Nothing to remove; treat as success (idempotent)
                return true;
            }
            string injection_path = Path.build_filename(game_dir, state.injection_file);
            string ini_path = Path.build_filename(game_dir, "OptiScaler.ini");
            string backup_path = injection_path + ".b";
            bool ok = true;
            try {
            // Remove any supporting files recorded in state
                if (stored != null) {
                    foreach (var rel in stored.installed_files) {
                        string full = Path.build_filename(game_dir, rel);
                        if (FileUtils.test(full, FileTest.IS_REGULAR)) {
                            ProtonPlus.Utils.Filesystem.delete_file(full);
                        } else if (FileUtils.test(full, FileTest.IS_DIR)) {
                        // Synchronous best-effort recursive delete using internal helper below
                            delete_dir_recursive(full);
                        }
                    }
                }
                if (FileUtils.test(injection_path, FileTest.IS_REGULAR)) {
                    if (!ProtonPlus.Utils.Filesystem.delete_file(injection_path)) {
                        message("OptiScaler remove: failed to delete injection file");
                        ok = false;
                    }
                }
                if (FileUtils.test(ini_path, FileTest.IS_REGULAR)) {
                    if (!ProtonPlus.Utils.Filesystem.delete_file(ini_path)) {
                        message("OptiScaler remove: failed to delete ini file");
                        ok = false;
                    }
                }
                // Restore backup if present and original now gone
                if (FileUtils.test(backup_path, FileTest.IS_REGULAR) && !FileUtils.test(injection_path, FileTest.IS_REGULAR)) {
                    if (FileUtils.rename(backup_path, injection_path) != 0) {
                        message("OptiScaler remove: failed to restore backup");
                        ok = false;
                    }
                }
            } catch (Error e) {
                message(e.message);
                ok = false;
            }
            // Launch options cleanup (conservative): only if we recorded we applied and can safely revert to original
            StateEntry? entry = stored;
            if (entry != null && entry.applied_override && entry.original_launch_options != null) {
                var steam_launcher = steam_game.launcher as ProtonPlus.Models.Launchers.Steam;
                if (steam_launcher != null) {
                    steam_game.change_launch_options(entry.original_launch_options, steam_launcher.profile.localconfig_path);
                }
            }
            if (entry != null) {
                saved_state.unset(key);
                save_state();
            }
            return ok;
        }

        /* ===== Helpers: persistence, hashing, ini editing ===== */
        private string get_state_dir() {
            string base_dir = Environment.get_user_data_dir();
            string dir = Path.build_filename(base_dir, Config.APP_NAME, CACHE_DIR_NAME);
            if (!FileUtils.test(dir, FileTest.IS_DIR)) {
                try { DirUtils.create_with_parents(dir, 0755); } catch (Error e) { message(e.message); }
            }
            return dir;
        }

        private string get_state_file() {
            return Path.build_filename(get_state_dir(), STATE_FILE_NAME);
        }

        private void load_state() {
            string path = get_state_file();
            if (!FileUtils.test(path, FileTest.IS_REGULAR)) return;
            try {
                var content = ProtonPlus.Utils.Filesystem.get_file_content(path);
                var parser = new Json.Parser();
                parser.load_from_data(content, -1);
                var root = parser.get_root();
                if (root == null) return;
                var obj = root.get_object();
                if (obj == null) return;
                foreach (string key in obj.get_members()) {
                    var entry_obj = obj.get_object_member(key);
                    var e = new StateEntry();
                    e.injection = entry_obj.get_string_member("injection");
                    if (entry_obj.has_member("version")) e.version = entry_obj.get_string_member("version");
                    if (entry_obj.has_member("hash")) e.hash = entry_obj.get_string_member("hash");
                    if (entry_obj.has_member("backup_created")) e.backup_created = entry_obj.get_boolean_member("backup_created");
                    if (entry_obj.has_member("original_launch_options")) e.original_launch_options = entry_obj.get_string_member("original_launch_options");
                    if (entry_obj.has_member("applied_override")) e.applied_override = entry_obj.get_boolean_member("applied_override");
                    if (entry_obj.has_member("exe_dir")) e.exe_dir = entry_obj.get_string_member("exe_dir");
                    if (entry_obj.has_member("installed_files")) {
                        var arr = entry_obj.get_array_member("installed_files");
                        for (uint i = 0; i < arr.get_length(); i++) {
                            e.installed_files.add(arr.get_string_element(i));
                        }
                    }
                    saved_state.set(key, e);
                }
            } catch (Error e) { message("OptiScaler state load failed: %s".printf(e.message)); }
        }

        private void save_state() {
            try {
                var builder = new Json.Builder();
                builder.begin_object();
                foreach (var key in saved_state.keys) {
                    var e = saved_state.get(key);
                    builder.set_member_name(key);
                    builder.begin_object();
                    builder.set_member_name("injection"); builder.add_string_value(e.injection);
                    if (e.version != null) { builder.set_member_name("version"); builder.add_string_value(e.version); }
                    if (e.hash != null) { builder.set_member_name("hash"); builder.add_string_value(e.hash); }
                    builder.set_member_name("backup_created"); builder.add_boolean_value(e.backup_created);
                    if (e.original_launch_options != null) { builder.set_member_name("original_launch_options"); builder.add_string_value(e.original_launch_options); }
                    builder.set_member_name("applied_override"); builder.add_boolean_value(e.applied_override);
                    if (e.exe_dir != null) { builder.set_member_name("exe_dir"); builder.add_string_value(e.exe_dir); }
                    // installed_files array
                    builder.set_member_name("installed_files");
                    builder.begin_array();
                    foreach (var f in e.installed_files) builder.add_string_value(f);
                    builder.end_array();
                    builder.end_object();
                }
                builder.end_object();
                var gen = new Json.Generator();
                gen.set_root(builder.get_root());
                string data = gen.to_data(null);
                ProtonPlus.Utils.Filesystem.atomic_write(get_state_file(), data);
            } catch (Error e) { message("OptiScaler state save failed: %s".printf(e.message)); }
        }

        private string? compute_sha256(string path) {
            try {
                FileStream fs = FileStream.open(path, "rb");
                if (fs == null) return null;
                var checksum = new Checksum(ChecksumType.SHA256);
                uint8[] buf = new uint8[8192];
                size_t r = 0;
                while ((r = fs.read(buf)) > 0) {
                    checksum.update(buf, r);
                }
                // FileStream will be closed when going out of scope
                return checksum.get_string();
            } catch (Error e) { message(e.message); return null; }
        }

        private bool apply_ini_spoof_toggle(string ini_path, bool disable) {
            if (!FileUtils.test(ini_path, FileTest.IS_REGULAR)) return false;
            try {
                var content = ProtonPlus.Utils.Filesystem.get_file_content(ini_path);
                string[] lines = content.split("\n");
                bool found = false;
                for (int i = 0; i < lines.length; i++) {
                    var l = lines[i].strip();
                    if (l.has_prefix("Dxgi=")) {
                        lines[i] = "Dxgi=" + (disable ? "false" : "auto");
                        found = true;
                        break;
                    }
                }
                if (!found && disable) {
                    content = content + "\nDxgi=false\n";
                } else if (found) {
                    content = string.joinv("\n", lines);
                }
                ProtonPlus.Utils.Filesystem.modify_file(ini_path, content);
                return true;
            } catch (Error e) { message(e.message); return false; }
        }

        /* ==== Executable path heuristics (Unreal Shipping.exe detection) ==== */
        private string find_exe_dir(string base_dir) {
        // Search depth-limited for *Shipping.exe inside Binaries/Win64
            try {
                string? found = null;
                recursive_scan(base_dir, 0, 4, (path) => {
                    if (found != null) return; // early exit
                    if (path.has_suffix("Shipping.exe") && path.index_of("Binaries" + Path.DIR_SEPARATOR_S + "Win64") >= 0) {
                        found = Path.get_dirname(path);
                    }
                });
                if (found != null) return found;
            } catch (Error e) { message(e.message); }
            return base_dir; // fallback
        }

        private delegate void FileMatch(string path);

        private void recursive_scan(string dir, int depth, int max_depth, FileMatch cb) throws Error {
            if (depth > max_depth) return;
            Dir d = Dir.open(dir);
            string? name;
            while ((name = d.read_name()) != null) {
                if (name == "." || name == "..") continue;
                string path = Path.build_filename(dir, name);
                if (FileUtils.test(path, FileTest.IS_DIR)) {
                    recursive_scan(path, depth + 1, max_depth, cb);
                } else if (FileUtils.test(path, FileTest.IS_REGULAR)) {
                    cb(path);
                }
            }
        }

        // Discover directory containing OptiScaler core files, accommodating nested archive structures
        private bool find_core_dir(string root, out string core_dir, out string dll_name, out string ini_name) {
            core_dir = root; dll_name = "OptiScaler.dll"; ini_name = "OptiScaler.ini";
        // Fast path
            if (FileUtils.test(Path.build_filename(root, dll_name), FileTest.IS_REGULAR) && FileUtils.test(Path.build_filename(root, ini_name), FileTest.IS_REGULAR)) {
                return true;
            }
            // Recursive limited search depth 3
            bool found = false;
            string found_dir = root; string found_dll = dll_name; string found_ini = ini_name;
            try {
                recursive_scan(root, 0, 3, (path) => {
                    if (found) return;
                    string basename_str = Path.get_basename(path);
                    string lower = basename_str;
                    // attempt lowercase conversion; ignore errors
                    try { lower = basename_str.down(); } catch (Error e) {}
                    if (lower == "optiscaler.dll") {
                        string dir = Path.get_dirname(path);
                        string ini_candidate = Path.build_filename(dir, "OptiScaler.ini");
                        if (!FileUtils.test(ini_candidate, FileTest.IS_REGULAR)) {
                        // try lowercase variant
                            string ini_lower = Path.build_filename(dir, "optiscaler.ini");
                            if (FileUtils.test(ini_lower, FileTest.IS_REGULAR)) ini_candidate = ini_lower;
                        }
                        if (FileUtils.test(ini_candidate, FileTest.IS_REGULAR)) {
                            found = true;
                            found_dir = dir;
                            found_dll = basename_str; // preserve actual case
                            found_ini = Path.get_basename(ini_candidate);
                        }
                    }
                });
            } catch (Error e) { message(e.message); }
            if (found) {
                core_dir = found_dir; dll_name = found_dll; ini_name = found_ini; return true;
            }
            return false;
        }

        // Minimal recursive directory delete (non-async) used only for cleanup of known installed files.
        private void delete_dir_recursive(string dir) {
            try {
                Dir d = Dir.open(dir);
                string? name;
                while ((name = d.read_name()) != null) {
                    if (name == "." || name == "..") continue;
                    string path = Path.build_filename(dir, name);
                    if (FileUtils.test(path, FileTest.IS_DIR)) {
                        delete_dir_recursive(path);
                        Posix.rmdir(path);
                    } else {
                        ProtonPlus.Utils.Filesystem.delete_file(path);
                    }
                }
                Posix.rmdir(dir);
            } catch (Error e) { message(e.message); }
        }
    }

    public class LaunchOptions {
        // Insert or merge WINEDLLOVERRIDES for an injection target.
        // Rules:
        // 1. If existing WINEDLLOVERRIDES variable present, merge injection=n,b without duplication.
        // 2. If absent, create new WINEDLLOVERRIDES=entry immediately left of %command% if present, else append at end.
        // 3. Preserve any existing overrides ordering; our injection is appended within the variable list.
        public static string ensure_override(string current, string injection_basename) {
            string needle = "WINEDLLOVERRIDES=";
            string pair = injection_basename + "=n,b"; // Typical override semantics for local native + builtin fallback

            int idx = current.index_of(needle);
            if (idx >= 0) {
            // Extract until first space following the variable or end of string
                int space = current.index_of(" ", idx);
                string prefix;
                string tail;
                if (space < 0) {
                    prefix = current.substring(0, current.length);
                    tail = "";
                } else {
                    prefix = current.substring(0, space);
                    tail = current.substring(space + 1);
                }

                // prefix contains e.g. '... WINEDLLOVERRIDES=foo=n,b;bar=n'
                int eq = prefix.index_of(needle) + needle.length;
                string list = prefix.substring(eq);
                // Avoid adding if already present (match injection name followed by =)
                Regex r;
                try { r = new Regex("(^|;|:)" + Regex.escape_string(injection_basename) + "="); }
                catch (Error e) { return current; }
                if (r.match(list)) {
                    return current; // already present
                }
                // Append with semicolon separator (Steam typically accepts both ; and :) ; keep using ;
                if (list.length > 0 && !list.has_suffix(";")) {
                    list += ";";
                }
                list += pair;
                var rebuilt = prefix.substring(0, eq) + list;
                return (space < 0) ? rebuilt : rebuilt + " " + tail;
            } else {
            // No existing variable
                string insertion = needle + pair;
                int cmd = current.index_of("%command%");
                if (cmd >= 0) {
                // Insert before %command% (with trailing space if needed)
                // Find start of %command% token (could be quoted or preceded by space)
                    return current.substring(0, cmd) + insertion + " " + current.substring(cmd);
                } else if (current.strip().length == 0) {
                    return insertion + " %command%"; // create canonical form
                } else {
                // Append at end
                    string current_str = current;
                    if (!current_str.has_suffix(" ")) current_str = current_str + " ";
                    return current_str + insertion;
                }
            }
        }
    }
}