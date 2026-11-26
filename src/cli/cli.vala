namespace ProtonPlus.CLI {
    private const string CMD_VERSION = "version";
    private const string CMD_HELP = "help";
    private const string CMD_LIST = "list";
    private const string CMD_INSTALL = "install";
    private const string CMD_UNINSTALL = "uninstall";
    private const string CMD_UPDATE = "update";
    private const string CMD_SEARCH = "search";
    private const string CMD_OUTDATED = "outdated";
    private const string CMD_SYNC = "sync";
    private const string CMD_CLEANUP = "cleanup";

    private const string CMD_STEAM_KEY_REPAIR = "steam-key-repair";
    private const string STEAM_KEY_REPAIR_USAGE = "steam-key-repair <steam_launcher_id> {preview | apply <preview_token> <key> <owner_directory> [<appid>=<directory> ...] | resume}";

    private const string OPT_LATEST = "latest";
    private const string OPT_ALL = "all";
    private const string OPT_JSON = "--json";

    private const string SEARCH_USAGE = "search [--json] [query]";
    private const string OUTDATED_USAGE = "outdated [--json] [launcher_id]";
    private const string SYNC_USAGE = "sync [launcher_id]";

    private const string LIST_USAGE = "list [launcher_id]";
    private const string INSTALL_USAGE = "install <launcher_id> <runner_id> [latest]";
    private const string UNINSTALL_USAGE = "uninstall <launcher_id> {all | <runner_id> [all]}";
    private const string UPDATE_USAGE = "update all | update <launcher_id> [runner_id]";

    public static bool changes_installed_tools (string[] args) {
        return args.length >= 2 && tool_command_usage (args[1]) != null && has_valid_tool_arguments (args);
    }

    private static string? tool_command_usage (string command) {
        switch (command) {
        case CMD_INSTALL:
            return INSTALL_USAGE;
        case CMD_UNINSTALL:
            return UNINSTALL_USAGE;
        case CMD_UPDATE:
            return UPDATE_USAGE;
        default:
            return null;
        }
    }

    private static bool has_valid_tool_arguments (string[] args) {
        for (var i = 2; i < args.length; i++) {
            if (args[i].strip () == "" || args[i].has_prefix ("-"))
                return false;
        }

        switch (args[1]) {
        case CMD_INSTALL:
            return args.length == 4 || (args.length == 5 && args[4] == OPT_LATEST);
        case CMD_UNINSTALL:
            return args.length == 4 || (args.length == 5 && args[3] != OPT_ALL && args[4] == OPT_ALL);
        case CMD_UPDATE:
            return args.length == 3 || (args.length == 4 && args[2] != OPT_ALL);
        default:
            return false;
        }
    }

    public interface CliOutputSink : Object {
        public abstract void write_stdout (string text);
        public abstract void write_stderr (string text);
        public abstract void flush_stdout ();
    }

    public class TerminalCliOutputSink : Object, CliOutputSink {
        public void write_stdout (string text) {
            print (text);
        }

        public void write_stderr (string text) {
            printerr (text);
        }

        public void flush_stdout () {
            stdout.flush ();
        }
    }

    public class RecordingCliOutputSink : Object, CliOutputSink {
        public string stdout_text { get; private set; default = ""; }
        public string stderr_text { get; private set; default = ""; }

        public void write_stdout (string text) {
            stdout_text += text;
        }

        public void write_stderr (string text) {
            stderr_text += text;
        }

        public void flush_stdout () {
        }
    }

    private class Output {
        private const string RESET = "\033[0m";
        private const string BOLD = "\033[1m";
        private const string RED = "\033[31m";
        private const string GREEN = "\033[32m";
        private const string YELLOW = "\033[33m";
        private const string BLUE = "\033[34m";
        private CliOutputSink sink;

        public Output (CliOutputSink sink) {
            this.sink = sink;
        }

        public void info (string format, ...) {
            var args = va_list ();
            sink.write_stdout (format.vprintf (args));
        }

        public void bold_line (string text) {
            sink.write_stdout (BOLD + text + RESET + "\n");
        }

        public void success (string format, ...) {
            var args = va_list ();
            sink.write_stdout (GREEN + format.vprintf (args) + RESET);
        }

        public void error (string format, ...) {
            var args = va_list ();
            sink.write_stderr (RED + format.vprintf (args) + RESET);
        }

        public void warning (string format, ...) {
            var args = va_list ();
            sink.write_stdout (YELLOW + format.vprintf (args) + RESET);
        }

        public void header (string format, ...) {
            var args = va_list ();
            sink.write_stdout (BOLD + BLUE + format.vprintf (args) + RESET);
        }

        public void flush_stdout () {
            sink.flush_stdout ();
        }
    }

    // Buffer presentation rows so every column fits its header and contents.
    private class TableRow : Object {
        public string[] cells;
        public string? heading;

        public TableRow (string[] cells, string? heading = null) {
            this.cells = cells;
            this.heading = heading;
        }
    }

    private class Table : Object {
        private string[] labels;
        private int[] widths;
        private Gee.ArrayList<TableRow> rows = new Gee.ArrayList<TableRow> ();

        public Table (string[] labels) {
            this.labels = labels;
            widths = new int[labels.length];
            for (var i = 0; i < labels.length; i++)
                widths[i] = display_width (labels[i]);
        }

        public void add (string[] cells, string? heading = null) {
            assert (cells.length == labels.length);
            rows.add (new TableRow (cells, heading));
            for (var i = 0; i < cells.length; i++)
                widths[i] = int.max (widths[i], display_width (cells[i]));
        }

        public bool is_empty () {
            return rows.is_empty;
        }

        private static int display_width (string value) {
            var width = 0;
            var index = 0;
            unichar character;
            while (value.get_next_char (ref index, out character)) {
                if (!character.iszerowidth ())
                    width += character.iswide () ? 2 : 1;
            }
            return width;
        }

        private void print_row (Output output, string[] cells, bool labels = false) {
            var line = new StringBuilder ("  ");
            for (var i = 0; i < cells.length; i++) {
                line.append (cells[i]);
                if (i + 1 < cells.length)
                    line.append (string.nfill (widths[i] - display_width (cells[i]) + 2, ' '));
            }
            if (labels)
                output.bold_line (line.str);
            else
                output.info ("%s\n", line.str);
        }

        public void print (Output output, bool leading_blank = true) {
            if (rows.size == 0)
                return;
            if (rows[0].heading == null) {
                if (leading_blank)
                    output.info ("\n");
                print_row (output, labels, true);
            }
            var first_row = true;
            foreach (var row in rows) {
                if (row.heading != null) {
                    if (!first_row || leading_blank)
                        output.info ("\n");
                    output.bold_line ("%s:".printf (row.heading));
                    print_row (output, labels, true);
                }
                print_row (output, row.cells);
                first_row = false;
            }
        }
    }

    public class Handler {
        private Gee.LinkedList<Models.Launcher> launchers;
        /* Production discovers launchers at command time.  Tests may provide
         * a fully temporary collection so command routing never touches a
         * host launcher directory. */
        private Gee.LinkedList<Models.Launcher>? fixture_launchers;
        private ulong progress_updated_handler_id = 0;
        private ulong steam_restart_recording_failed_handler_id = 0;
        private Output output;
        public CliOutputSink output_sink { get; private set; }

        public Handler (Gee.LinkedList<Models.Launcher>? fixture_launchers = null,
            CliOutputSink? output_sink = null) {
            this.fixture_launchers = fixture_launchers;
            this.output_sink = output_sink ?? new TerminalCliOutputSink ();
            output = new Output (this.output_sink);
        }

        public async int run (string[] args) {
            if (args.length < 2) {
                print_usage ();
                return 1;
            }

            var command = args[1];
            if (command == CMD_VERSION) {
                output.info ("ProtonPlus %s\n", Config.APP_VERSION);
                return 0;
            }

            if (command == CMD_HELP) {
                print_usage ();
                return 0;
            }

            if (command == CMD_CLEANUP)
                return yield handle_cleanup (args);

            if (command == CMD_STEAM_KEY_REPAIR)
                return yield handle_steam_key_repair (args);

            var mutation_usage = tool_command_usage (command);
            var changes_tools = mutation_usage != null;
            if (mutation_usage != null && !has_valid_tool_arguments (args))
                return usage_error (mutation_usage);

            if (!changes_tools && command != CMD_LIST && command != CMD_SEARCH &&
                command != CMD_OUTDATED && command != CMD_SYNC) {
                output.error (_ ("Error: Unknown command '%s'\n"), command);
                print_usage ();
                return 1;
            }

            if (command == CMD_INSTALL || command == CMD_UPDATE)
                progress_updated_handler_id = Utils.DownloadManager.instance.progress_updated.connect (on_progress_updated);
            if (changes_tools) {
                steam_restart_recording_failed_handler_id = Services.InstallationService.instance.steam_restart_recording_failed.connect ((job, message) => {
                    output.warning (_ ("Warning: %s\n"), message);
                });
            }

            try {
                if (!yield load_launchers (!changes_tools))
                    return 1;

                switch (command) {
                    case CMD_LIST:
                        return handle_list (args);
                    case CMD_SEARCH:
                        return handle_search (args);
                    case CMD_OUTDATED:
                        return yield handle_outdated (args);
                    case CMD_SYNC:
                        return yield handle_sync (args);
                    case CMD_INSTALL:
                        return yield handle_install (args);
                    case CMD_UNINSTALL:
                        return yield handle_uninstall (args);
                    case CMD_UPDATE:
                        return yield handle_update (args);
                    default:
                        return 1;
                }
            } finally {
                disconnect_runtime_signals ();
            }
        }

        private async int handle_steam_key_repair (string[] args) {
            if (args.length < 4 || (args[3] == "apply" ? args.length < 7
                : args.length != 4 || (args[3] != "preview" && args[3] != "resume")))
                return usage_error (STEAM_KEY_REPAIR_USAGE);
            if (!yield load_launchers (true))
                return 1;
            var steam = find_launcher (args[2]) as Models.Launchers.Steam;
            if (steam == null) {
                output.error (_ ("Select a Steam launcher for this repair.\n"));
                return 1;
            }
            try {
                var sessions = Services.SteamSessionService.instance;
                var manager = new Services.SteamRestartManager (sessions, new Services.SteamRestartStateStore ());
                var configuration = new Services.SteamConfigurationService (sessions, manager);
                var repair = new Services.SteamKeyRepair (steam, sessions, manager, configuration);
                switch (args[3]) {
                case "preview":
                    print_steam_key_preview (repair, repair.preview ());
                    return 0;
                case "apply":
                    var assignments = new Gee.HashMap<string, string> ();
                    for (var i = 7; i < args.length; i++) {
                        var pair = args[i].split ("=", 2);
                        if (pair.length != 2 || assignments.has_key (pair[0]))
                            return usage_error (STEAM_KEY_REPAIR_USAGE);
                        assignments.set (pair[0], pair[1]);
                    }
                    repair.apply (args[4], args[5], args[6], assignments);
                    break;
                case "resume":
                    repair.resume ();
                    break;
                }
                output.info (_ ("Steam compatibility key repair completed.\n"));
                return 0;
            } catch (Error e) {
                output.error (_ ("Steam compatibility key repair: %s\n"), e.message);
                return 1;
            }
        }

        private void print_steam_key_preview (Services.SteamKeyRepair repair, Services.SteamKeyRepairPreview preview) {
            if (preview.recovery_available) {
                output.info (_ ("An interrupted repair is available. Exit Steam and run this command with resume.\n"));
                return;
            }
            var keys = new Gee.TreeMap<string, int> ();
            foreach (var claim in preview.claims) {
                var key = claim.key.ascii_down ();
                keys.set (key, (keys.has_key (key) ? keys.get (key) : 0) + 1);
            }
            var reported = new Gee.HashSet<string> ();
            foreach (var claim in preview.claims) {
                var key = claim.key;
                if (keys.get (key.ascii_down ()) < 2 || !reported.add (key.ascii_down ()))
                    continue;
                output.info (_ ("\nShared Steam key %s\n"), Shell.quote (key));
                foreach (var slot in preview.claims) {
                    if (slot.key.ascii_down () != key.ascii_down ())
                        continue;
                    if (slot.replacement == "") {
                        output.info (_ ("  %s (external or ownership uncertain)\n"), Shell.quote (slot.path));
                        continue;
                    }
                    var dir = Path.get_basename (slot.path);
                    output.info (_ ("  %s (fresh key %s)\n"), Shell.quote (dir), Shell.quote (slot.replacement));
                    var conflict = repair.owner_conflict (preview, key, dir);
                    if (conflict == null)
                        output.info (_ ("    Can retain the historical key.\n"));
                    else
                        output.info (_ ("    Cannot retain the historical key: %s\n"), conflict);
                }
                var appids = new Gee.TreeSet<uint> ((a, b) => a < b ? -1 : a == b ? 0 : 1);
                preview.mappings.foreach ((appid, value) => {
                    if (value.ascii_down () == key.ascii_down ())
                        appids.add (appid);
                });
                foreach (var appid in appids) {
                    if (appid == 0)
                        output.info (_ ("  AppID 0 (global default, also used by games that inherit it)\n"));
                    else
                        output.info (_ ("  AppID %u\n"), appid);
                }
                foreach (var record in preview.pending) {
                    var intent = record.receipt.configuration_intent;
                    if (intent != null && intent.operation == Models.SteamConfigurationOperation.COMPATIBILITY_MAPPING
                        && (preview.affects (intent, key)
                            || (!intent.desired_present && intent.field_id != "0" && preview.mappings.get (0) == key)))
                        output.info (_ ("  Pending ProtonPlus edit for AppID %s: %s\n"),
                            intent.field_id, intent.desired_present ? Shell.quote (intent.desired) : _ ("inherit default"));
                }
            }
            if (reported.is_empty)
                output.info (_ ("No duplicate Steam compatibility keys were found.\n"));
            else
                output.info (_ ("\nPreview token %s\n"), preview.token);
        }

        private void disconnect_runtime_signals () {
            if (progress_updated_handler_id != 0) {
                Utils.DownloadManager.instance.disconnect (progress_updated_handler_id);
                progress_updated_handler_id = 0;
            }
            if (steam_restart_recording_failed_handler_id != 0) {
                Services.InstallationService.instance.disconnect (steam_restart_recording_failed_handler_id);
                steam_restart_recording_failed_handler_id = 0;
            }
        }

        private int handle_list (string[] args) {
            if (args.length > 3 || (args.length == 3 && args[2].has_prefix ("-")))
                return usage_error (LIST_USAGE);
            if (args.length < 3) {
                print_launcher_table (false);
                return 0;
            }

            var launcher = find_launcher (args[2]);
            if (launcher == null) {
                return 1;
            }

            var found = false;
            var table = new Table ({ _ ("Runner ID"), _ ("Version"), _ ("Name") });
            foreach (var group in launcher.groups) {
                group.refresh_installed_state (false);
                var installed = group.get_installed_tool_snapshot ();
                var group_found = false;
                foreach (var tool in group.tools) {
                    if (!(tool is Models.Tools.TinkerGame) && !(tool is Models.Tools.SteamTinkerLaunch))
                        continue;
                    var entry = tool.resolved_installed_entry;
                    if (entry == null)
                        continue;
                    table.add ({ get_runner_id (tool), entry.tag != "" ? entry.tag : "—", tool.title },
                        group_found ? null : group.title);
                    group_found = true;
                    found = true;
                }
                foreach (var entry in installed) {
                    // Preserve the former directory helper's runtime exclusion.
                    if (entry.directory_name == "LegacyRuntime")
                        continue;
                    var runner = group.installed_tool_inventory.get_provider_tool_for_entry (entry);
                    if (runner == null)
                        continue;
                    table.add ({ get_runner_id (runner), entry.tag != "" ? entry.tag : "—", entry.display_title },
                        group_found ? null : group.title);
                    group_found = true;
                    found = true;
                }
            }
            table.print (output, false);
            if (!found) {
                output.warning (_ ("No runners installed\n"));
            }
            return 0;
        }

        private int handle_search (string[] args) {
            bool json;
            string? query;
            if (!parse_query_args (args, SEARCH_USAGE, out json, out query))
                return 1;

            var terms = (query ?? "").casefold ().split_set (" \t\r\n");
            var table = new Table ({ _ ("Package ID"), _ ("Name") });
            var packages = new Json.Array ();
            foreach (var launcher in launchers) {
                foreach (var group in launcher.groups) {
                    foreach (var tool in group.tools) {
                        if (!is_available_in_catalog (tool))
                            continue;
                        var package_id = get_package_id (tool);
                        var searchable = "%s\n%s\n%s".printf (package_id, tool.title, tool.description).casefold ();
                        if (!matches_search_terms (searchable, terms))
                            continue;
                        if (json) {
                            var package = make_package (tool);
                            package.set_string_member ("category", group.id);
                            package.set_string_member ("description", tool.description);
                            packages.add_object_element (package);
                        } else {
                            table.add ({ package_id, tool.title });
                        }
                    }
                }
            }
            if (json)
                print_packages (packages);
            else if (table.is_empty ())
                output.info (_ ("No matching runners\n"));
            else
                table.print (output, false);
            return 0;
        }

        private bool matches_search_terms (string text, string[] terms) {
            foreach (var term in terms)
                if (term != "" && !text.contains (term))
                    return false;
            return true;
        }

        private bool is_available_in_catalog (Models.Tool tool) {
            return tool.is_visible_in_catalog (Globals.SETTINGS) &&
                !(tool is Models.Tools.SteamTinkerLaunch) &&
                (!(tool is Models.Tools.TinkerGame) || Services.TinkerGameWorkflow.is_supported_on (tool.group.launcher));
        }

        private async int handle_outdated (string[] args) {
            bool json;
            string? launcher_id;
            if (!parse_query_args (args, OUTDATED_USAGE, out json, out launcher_id))
                return 1;
            var scope = get_launcher_scope (launcher_id, !json);
            if (scope == null)
                return 1;

            var table = new Table ({ _ ("Package ID"), _ ("Installed"), _ ("Available"), _ ("Variant") });
            var packages = new Json.Array ();
            var failed = false;
            foreach (var tool in collect_latest_runners (scope, false)) {
                Gee.List<Services.AvailableToolUpdate> updates;
                var code = yield Services.InstallationService.instance.find_available_updates (tool, out updates);
                foreach (var update in updates) {
                    var latest = update.release.source_tag != "" ? update.release.source_tag : update.release.title;
                    if (json) {
                        var package = make_package (tool);
                        set_optional_string (package, "installed_version", update.installed_version);
                        package.set_string_member ("latest_version", latest);
                        set_optional_string (package, "variant_id", update.variant_id);
                        packages.add_object_element (package);
                    } else {
                        table.add ({ get_package_id (tool), update.installed_version != "" ? update.installed_version : "—",
                            latest, update.variant_id != "" ? update.variant_id : "—" });
                    }
                }
                if (code != ReturnCode.UPDATE_AVAILABLE && code != ReturnCode.NOTHING_TO_UPDATE) {
                    output.error (_ ("Error: Could not check %s: %s\n"), get_package_id (tool), get_return_code_message (code));
                    failed = true;
                }
            }
            if (json)
                print_packages (packages);
            else if (!table.is_empty ())
                table.print (output, false);
            else if (!failed)
                output.info (_ ("No updates available\n"));
            return failed ? 1 : 0;
        }

        private async int handle_sync (string[] args) {
            if (args.length > 3 || (args.length == 3 && args[2].has_prefix ("--")))
                return usage_error (SYNC_USAGE);
            var scope = get_launcher_scope (args.length == 3 ? args[2] : null);
            if (scope == null)
                return 1;

            var seen = new Gee.HashSet<string> ();
            var refreshed = new Gee.HashMap<Models.Providers.ProviderDefinition, Models.ReleaseCatalog> ();
            var failed = false;
            foreach (var launcher in scope) {
                foreach (var group in launcher.groups) {
                    foreach (var tool in group.tools) {
                        var catalog = tool.release_catalog;
                        if (catalog == null || !is_available_in_catalog (tool) || !seen.add (tool.id))
                            continue;
                        var provider = tool as Models.Tools.ProviderTool;
                        var previous = provider != null ? refreshed.get (provider.definition) : null;
                        var result = yield catalog.sync (previous);
                        if (!result.succeeded) {
                            output.error (_ ("Error: Could not sync %s: %s\n"), get_package_id (tool),
                                get_return_code_message (result.code));
                            failed = true;
                        } else if (provider != null && previous == null) {
                            refreshed.set (provider.definition, catalog);
                        }
                    }
                }
            }
            if (!failed)
                output.success (_ ("Release cache is up to date\n"));
            return failed ? 1 : 0;
        }

        private async int handle_cleanup (string[] args) {
            if (args.length != 2)
                return usage_error (CMD_CLEANUP);
            if (FileUtils.test (Globals.CACHE_PATH, FileTest.EXISTS | FileTest.IS_SYMLINK) &&
                !yield Utils.CacheManager.clear_cache ()) {
                output.error (_ ("Error: Could not clear the cache\n"));
                return 1;
            }
            output.success (_ ("Cache cleared\n"));
            return 0;
        }

        private bool parse_query_args (string[] args, string usage, out bool json, out string? argument) {
            json = false;
            argument = null;
            for (var i = 2; i < args.length; i++) {
                if (args[i] == OPT_JSON && !json) {
                    json = true;
                } else if (argument == null && !args[i].has_prefix ("--")) {
                    argument = args[i];
                } else {
                    usage_error (usage);
                    return false;
                }
            }
            return true;
        }

        private int usage_error (string usage) {
            output.error (_ ("Usage: %s\n"), "protonplus " + usage);
            return 1;
        }

        private Gee.LinkedList<Models.Launcher>? get_launcher_scope (string? launcher_id, bool show_available = true) {
            if (launcher_id == null)
                return launchers;
            var launcher = find_launcher (launcher_id, show_available);
            if (launcher == null)
                return null;
            var scope = new Gee.LinkedList<Models.Launcher> ();
            scope.add (launcher);
            return scope;
        }

        private string get_package_id (Models.Tool tool) {
            return "%s/%s".printf (get_launcher_id (tool.group.launcher), get_runner_id (tool));
        }

        private Json.Object make_package (Models.Tool tool) {
            var package = new Json.Object ();
            package.set_string_member ("id", get_package_id (tool));
            package.set_string_member ("launcher_id", get_launcher_id (tool.group.launcher));
            package.set_string_member ("tool_target_id", tool.group.launcher.tool_target_id);
            package.set_string_member ("runner_id", get_runner_id (tool));
            package.set_string_member ("name", tool.title);
            return package;
        }

        private void set_optional_string (Json.Object object, string name, string value) {
            if (value == "")
                object.set_null_member (name);
            else
                object.set_string_member (name, value);
        }

        private void print_packages (Json.Array packages) {
            var root = new Json.Object ();
            root.set_int_member ("schema_version", 1);
            root.set_array_member ("packages", packages);
            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (root);
            output_sink.write_stdout (Json.to_string (node, false) + "\n");
        }

        private async int handle_install (string[] args) {
            var launcher = find_launcher (args[2]);
            if (launcher == null) {
                return 1;
            }

            var runner = find_runner (launcher, args[3]);
            if (runner == null) {
                return 1;
            }

            if (!runner.is_visible_in_catalog (Globals.SETTINGS)) {
                output.error (_ ("Enable niche tools in Preferences to install %s.\n"), runner.title);
                return 1;
            }

            if (runner is Models.Tools.TinkerGame || runner is Models.Tools.SteamTinkerLaunch)
                return yield handle_specialized_tool (runner, CMD_INSTALL);

            var provider_tool = get_provider_tool (runner, CMD_INSTALL);
            if (provider_tool == null) {
                return 1;
            }

            var use_latest = args.length >= 5 && args[4] == OPT_LATEST;
            return use_latest ? yield install_latest (provider_tool) : yield install_interactive (provider_tool);
        }

        private async int handle_uninstall (string[] args) {
            var launcher = find_launcher (args[2]);
            if (launcher == null) {
                return 1;
            }

            if (args[3] == OPT_ALL) {
                return yield uninstall_launcher_all (launcher);
            }

            var runner = find_runner (launcher, args[3]);
            if (runner == null) {
                return 1;
            }

            if (runner is Models.Tools.TinkerGame || runner is Models.Tools.SteamTinkerLaunch)
                return yield handle_specialized_tool (runner, CMD_UNINSTALL);

            var provider_tool = get_provider_tool (runner, CMD_UNINSTALL);
            if (provider_tool == null) {
                return 1;
            }

            var uninstall_all = args.length >= 5 && args[4] == OPT_ALL;
            return uninstall_all ? yield uninstall_runner_all (provider_tool) : yield uninstall_interactive (provider_tool);
        }

        private async int handle_update (string[] args) {
            if (args[2] == OPT_ALL) {
                return yield update_all ();
            }

            var launcher = find_launcher (args[2]);
            if (launcher == null) {
                return 1;
            }

            if (args.length >= 4) {
                var runner = find_runner (launcher, args[3]);
                if (runner == null) {
                    return 1;
                }

                if (runner is Models.Tools.TinkerGame || runner is Models.Tools.SteamTinkerLaunch)
                    return yield handle_specialized_tool (runner, CMD_UPDATE);

                var provider_tool = get_provider_tool (runner, CMD_UPDATE);
                if (provider_tool == null) {
                    return 1;
                }
                return yield update_runner (provider_tool);
            }
            return yield update_launcher (launcher);
        }

        private async int handle_specialized_tool (Models.Tool tool, string operation) {
            var catalog = tool.release_catalog;
            if (catalog == null)
                return 1;
            Models.Release release;
            if (tool is Models.Tools.TinkerGame && operation != CMD_INSTALL) {
                // Removal uses local ownership. The update workflow looks up its release.
                release = new Models.Release (tool.title, "", "", new Models.Assets.Asset ("", ""),
                    "", 0, "", "", Models.Release.Kind.TINKER_GAME);
            } else {
                var loaded = yield catalog.load (true);
                if (!loaded.succeeded || catalog.releases.size == 0)
                    return 1;
                release = catalog.releases[0];
            }
            var job = new Services.InstallJob (release, tool);
            // Legacy IDs always refer to the legacy product. Keep removal and
            // updates available, but direct new users to its successor.
            if (job.steam_tinker_launch_context != null) {
                if (operation == CMD_INSTALL) {
                    output.error (_("SteamTinkerLaunch is legacy. Install tinkergame for a new installation.\n"));
                    return 1;
                }
                if (operation == CMD_UPDATE)
                    yield Services.InstallationService.instance.refresh_steam_tinker_launch_release (job);
            }
            ReturnCode result;
            if (operation == CMD_UNINSTALL)
                result = yield job.remove ();
            else if (operation == CMD_UPDATE)
                result = yield job.update ();
            else
                result = yield job.install ();
            var success = result == ReturnCode.RUNNER_INSTALLED || result == ReturnCode.RUNNER_UPDATED ||
                result == ReturnCode.RUNNER_REMOVED || result == ReturnCode.NOTHING_TO_UPDATE;
            if (!success)
                output.error ("%s: %s\n", tool.title, job.error_message ?? get_return_code_message (result));
            return success ? 0 : 1;
        }

        private async int install_latest (Models.Tools.ProviderTool provider_tool) {
            var catalog = provider_tool.release_catalog;
            if (catalog == null)
                return 1;
            var result = yield catalog.fetch_latest_eligible_release ();
            if (!result.succeeded) {
                output.error (_ ("Error: Failed to load releases: %s\n"), get_return_code_message (result.code));
                return 1;
            }

            if (!result.has_release) {
                output.error (_ ("Error: No releases are available\n"));
                return 1;
            }

            output.info (_ ("Installing %s Latest...\n"), provider_tool.title);
            provider_tool.group.refresh_installed_state ();
            var job = create_install_job (
                result.require_release (), provider_tool, Services.InstallJob.Mode.LATEST
            );
            var code = yield job.install ();
            output.info ("\r\033[2K\r");
            var success = code == ReturnCode.RUNNER_INSTALLED;
            if (success)
                output.success (_ ("Successfully installed %s Latest\n"), provider_tool.title);
            else
                output.error (_ ("Error: Installation failed: %s\n"), get_return_code_message (code));
            return success ? 0 : 1;
        }

        private async int install_interactive (Models.Tools.ProviderTool provider_tool) {
            var catalog = provider_tool.release_catalog;
            if (catalog == null)
                return 1;
            var code = yield load_runner_releases (provider_tool);
            if (code != ReturnCode.RELEASES_LOADED || catalog.releases.size == 0) {
                return 1;
            }

            output.header (_ ("Available releases for %s:\n"), provider_tool.title);
            var table = new Table ({ _ ("Number"), _ ("Release date"), _ ("Name") });
            for (var i = 0; i < catalog.releases.size; i++) {
                var release = catalog.releases[i] as Models.Release;
                table.add ({ (i + 1).to_string (),
                    release.release_date != "" ? release.release_date : "—", release.title });
            }
            table.print (output);

            var index = read_user_selection (_ ("Select release number"), (int) catalog.releases.size);
            if (index < 0) {
                return 1;
            }

            var selected = catalog.releases[index] as Models.Release;
            var job = create_install_job (selected, provider_tool);
            if (provider_tool.definition.has_release_variant_sets) {
                var variants = Models.VariantSelector.available_variants (selected, Globals.CPU_CAPABILITIES);
                if (variants.size > 1) {
                    var builds = new Table ({ _ ("Number"), _ ("Build") });
                    for (var variant_index = 0; variant_index < variants.size; variant_index++)
                        builds.add ({ (variant_index + 1).to_string (), Utils.safe_translate (variants[variant_index].name) });
                    builds.print (output);
                    var variant_index = read_user_selection (_ ("Select build number"), variants.size);
                    if (variant_index < 0)
                        return 1;
                    var variant = variants[variant_index];
                    job.set_selected_variant (variant.name, variant.resolved_asset (), variant.id);
                }
            }
            output.info (_ ("Installing %s...\n"), selected.title);
            code = yield job.install ();
            output.info ("\r\033[2K\r");
            var success = code == ReturnCode.RUNNER_INSTALLED;
            if (success)
                output.success (_ ("Successfully installed %s\n"), selected.title);
            else
                output.error (_ ("Error: Installation failed: %s\n"), get_return_code_message (code));
            return success ? 0 : 1;
        }

        private async int uninstall_interactive (Models.Tools.ProviderTool runner) {
            var installed = get_installed_entries (runner);
            if (installed.size == 0) {
                output.warning (_ ("No installed releases found for %s\n"), runner.title);
                return 0;
            }

            output.header (_ ("Installed releases for %s:\n"), runner.title);
            var table = new Table ({ _ ("Number"), _ ("Version"), _ ("Name") });
            for (var i = 0; i < installed.size; i++) {
                table.add ({ (i + 1).to_string (), installed[i].tag != "" ? installed[i].tag : "—",
                    installed[i].display_title });
            }
            table.print (output);

            var index = read_user_selection (_ ("Select release number"), installed.size);
            if (index < 0) {
                return 1;
            }

            return yield uninstall_single_release (runner, installed[index]);
        }

        private async int uninstall_runner_all (Models.Tools.ProviderTool runner) {
            var installed = get_installed_entries (runner);
            if (installed.size == 0) {
                output.warning (_ ("No installed releases found for %s\n"), runner.title);
                return 0;
            }

            output.info (_ ("Uninstalling all releases for %s...\n"), runner.title);
            var failed = false;
            foreach (var entry in installed) {
                var code = yield uninstall_single_release (runner, entry);
                if (code != 0) {
                    failed = true;
                }
            }
            return failed ? 1 : 0;
        }

        private async int uninstall_launcher_all (Models.Launcher launcher) {
            output.info (_ ("Uninstalling all releases for launcher %s...\n"), launcher.title);
            var failed = false;
            foreach (var group in launcher.groups) {
                foreach (var runner in group.tools) {
                    var provider_tool = runner as Models.Tools.ProviderTool;
                    if (provider_tool == null) {
                        continue;
                    }

                    var installed = get_installed_entries (provider_tool);
                    foreach (var entry in installed) {
                        var code = yield uninstall_single_release (provider_tool, entry);
                        if (code != 0) {
                            failed = true;
                        }
                    }
                }
            }
            return failed ? 1 : 0;
        }

        private async int uninstall_single_release (
            Models.Tools.ProviderTool runner,
            Models.InstalledToolEntry entry
        ) {
            var job = create_job (runner, entry);
            output.info (_ ("Uninstalling %s...\n"), entry.display_title);
            var code = yield job.remove ();
            var success = code == ReturnCode.RUNNER_REMOVED;
            if (success)
                output.success (_ ("Successfully uninstalled %s\n"), entry.display_title);
            else
                output.error (_ ("Error: Uninstallation failed: %s\n"), job.error_message ?? get_return_code_message (code));
            return success ? 0 : 1;
        }

        private async int update_all () {
            output.info (_ ("Updating all runners...\n"));
            var latest_runners = collect_latest_runners (launchers);
            return yield update_runner_batch (latest_runners);
        }

        private async int update_launcher (Models.Launcher launcher) {
            output.info (_ ("Updating runners for %s...\n"), launcher.title);
            var scoped = new Gee.LinkedList<Models.Launcher> ();
            scoped.add (launcher);
            var latest_runners = collect_latest_runners (scoped);
            return yield update_runner_batch (latest_runners);
        }

        private async int update_runner (Models.Tool runner) {
            var code = yield update_runner_with_progress (runner);
            switch (code) {
                case ReturnCode.RUNNER_UPDATED:
                    output.success (_ ("Successfully updated %s\n"), runner.title);
                    return 0;
                case ReturnCode.NOTHING_TO_UPDATE:
                    output.success (_ ("Already up to date: %s\n"), runner.title);
                    return 0;
                default:
                    output.error (_ ("Error: Failed to update %s: %s\n"), runner.title, get_return_code_message (code));
                    return 1;
            }
        }

        private Gee.LinkedList<Models.Tool> collect_latest_runners (
            Gee.LinkedList<Models.Launcher> scope, bool migrate_legacy_metadata = true
        ) {
            var latest_runners = new Gee.LinkedList<Models.Tool> ();
            var collected_runner_ids = new Gee.HashSet<string> ();

            foreach (var launcher in scope) {
                foreach (var group in launcher.groups) {
                    group.refresh_installed_state (migrate_legacy_metadata);
                    foreach (var tool in Services.InstallationService.instance.get_update_candidates (group)) {
                        if (collected_runner_ids.add (tool.id))
                            latest_runners.add (tool);
                    }
                }
            }

            return latest_runners;
        }

        private async int update_runner_batch (Gee.LinkedList<Models.Tool> runners) {
            if (runners.size == 0) {
                output.success (_ ("Already up to date\n"));
                return 0;
            }

            var failed = false;

            foreach (var runner in runners) {
                var code = yield update_runner (runner);
                if (code != 0)
                    failed = true;
            }
            return failed ? 1 : 0;
        }

        private async ReturnCode update_runner_with_progress (Models.Tool runner) {
            output.info (_ ("Updating %s...") + "\r", runner.title);
            output.flush_stdout ();

            var code = yield Services.InstallationService.instance.update_installed_tool (runner);

            output.info ("\r\033[2K\r");
            return code;
        }

        private async bool load_launchers (bool read_only) {
            if (fixture_launchers != null) {
                launchers = (!) fixture_launchers;
                return true;
            }
            var success = yield Models.Launcher.get_all (read_only, out launchers);
            if (!success || launchers == null) {
                output.error (_ ("Error: Failed to load launchers\n"));
                return false;
            }
            return true;
        }

        private async ReturnCode load_runner_releases (Models.Tools.ProviderTool provider_tool) {
            var catalog = provider_tool.release_catalog;
            if (catalog == null)
                return ReturnCode.INVALID_CONFIGURATION;
            var result = yield catalog.load (false);
            if (!result.succeeded)
                output.error (_ ("Error: Failed to load releases: %s\n"), get_return_code_message (result.code));
            else if (result.releases.size == 0)
                output.error (_ ("Error: No releases are available\n"));
            return result.code;
        }

        private Models.Launcher? find_launcher (string launcher_id, bool show_available = true) {
            foreach (var launcher in launchers) {
                if (matches_launcher_id (launcher, launcher_id)) {
                    return launcher;
                }
            }
            output.error (_ ("Error: Launcher '%s' not found\n"), launcher_id);
            if (show_available)
                print_available_launchers ();
            return null;
        }

        private Models.Tool? find_runner (Models.Launcher launcher, string runner_id) {
            foreach (var group in launcher.groups) {
                foreach (var runner in group.tools) {
                    if (matches_runner_id (runner, runner_id)) {
                        return runner;
                    }
                }
            }
            output.error (_ ("Error: Tool '%s' not found\n"), runner_id);
            print_available_runners (launcher);
            return null;
        }

        private Gee.List<Models.InstalledToolEntry> get_installed_entries (
            Models.Tools.ProviderTool runner
        ) {
            runner.group.refresh_installed_state ();
            var entries = runner.group.get_installed_tool_snapshot ();
            var installed = new Gee.ArrayList<Models.InstalledToolEntry> ();

            foreach (var entry in entries) {
                if (runner.group.installed_tool_inventory.get_provider_tool_for_entry (entry) == runner)
                    installed.add (entry);
            }
            return installed;
        }

        public static string get_launcher_id (Models.Launcher launcher) {
            return launcher.instance_id;
        }

        public static string get_runner_id (Models.Tool runner) {
            return runner.provider_id;
        }

        public static bool matches_launcher_id (Models.Launcher launcher, string launcher_id) {
            return get_launcher_id (launcher) == launcher_id || get_legacy_launcher_id (launcher) == launcher_id;
        }

        public static bool matches_runner_id (Models.Tool runner, string runner_id) {
            return get_runner_id (runner) == runner_id || get_legacy_runner_id (runner) == runner_id;
        }

        private static string get_legacy_launcher_id (Models.Launcher launcher) {
            return "%s-%s".printf (launcher.title.down ().replace (" ", "-"), launcher.get_installation_type_title ().down ());
        }

        private static string get_legacy_runner_id (Models.Tool runner) {
            return runner.title.down ().replace (" ", "-");
        }

        private Services.InstallJob create_job (
            Models.Tools.ProviderTool runner,
            Models.InstalledToolEntry entry
        ) {
            var release = new Models.Release (
                entry.display_title, "", "", new Models.Assets.Asset ("", ""), "", 0, "", entry.release_id
            );
            return create_install_job (
                release, runner, Services.InstallJob.Mode.VERSIONED, entry.path
            );
        }

        /* Keep the actual CLI routing and InstallationService lifecycle in
         * place while allowing fixture jobs to cover cancellation and durable
         * transaction failures without a network request. */
        protected virtual Services.InstallJob create_install_job (
            Models.Release release,
            Models.Tools.ProviderTool provider_tool,
            Services.InstallJob.Mode mode = Services.InstallJob.Mode.VERSIONED,
            string? installation_location = null
        ) {
            return new Services.InstallJob (release, provider_tool, mode, installation_location);
        }

        private Models.Tools.ProviderTool? get_provider_tool (Models.Tool runner, string operation) {
            var provider_tool = runner as Models.Tools.ProviderTool;
            if (provider_tool == null) {
                output.error (_ ("Error: Tool '%s' does not support %s\n"), runner.title, operation);
            }
            return provider_tool;
        }

        protected virtual string? read_selection_input () {
            return stdin.read_line ();
        }

        private int read_user_selection (string prompt, int max) {
            output.info ("\n%s: ", prompt);
            output.flush_stdout ();
            var input = read_selection_input ()?.strip () ?? "";

            if (input == "") {
                return -1;
            }

            int selection;
            unowned string remainder;
            if (!int.try_parse (input, out selection, out remainder, 10) || remainder != "") {
                output.error (_ ("Error: Invalid input, please enter a number\n"));
                return -1;
            }

            if (selection <= 0 || selection > max) {
                output.error (_ ("Error: Selection out of range\n"));
                return -1;
            }
            return selection - 1;
        }

        private void print_usage () {
            output.header (_ ("Usage:\n"));
            output.info ("\n  protonplus <command> [options]\n\n");
            output.header (_ ("Commands:\n"));
            var table = new Table ({ _ ("Command"), _ ("Description") });
            table.add ({ "version", _ ("Show version") });
            table.add ({ "help", _ ("Show this help") });
            table.add ({ LIST_USAGE, _ ("List launchers or installed runners") });
            table.add ({ SEARCH_USAGE, _ ("Search available runners") });
            table.add ({ OUTDATED_USAGE, _ ("List available runner updates") });
            table.add ({ SYNC_USAGE, _ ("Refresh cached release metadata") });
            table.add ({ CMD_CLEANUP, _ ("Clear cached releases and downloads") });
            table.add ({ INSTALL_USAGE, _ ("Install runner") });
            table.add ({ UNINSTALL_USAGE, _ ("Uninstall runner") });
            table.add ({ UPDATE_USAGE, _ ("Update runner") });
            table.add ({ STEAM_KEY_REPAIR_USAGE, _ ("Preview or resolve shared Steam compatibility keys") });
            table.print (output);
        }

        private void print_available_launchers () {
            output.header (_ ("\nAvailable launchers:\n"));
            print_launcher_table ();
        }

        private void print_launcher_table (bool leading_blank = true) {
            var table = new Table ({ _ ("Launcher ID"), _ ("Name") });
            foreach (var launcher in launchers)
                table.add ({ get_launcher_id (launcher), launcher.title });
            table.print (output, leading_blank);
        }

        private void print_available_runners (Models.Launcher launcher) {
            output.header (_ ("\nAvailable runners for %s:\n"), launcher.title);
            var table = new Table ({ _ ("Runner ID"), _ ("Name") });
            foreach (var group in launcher.groups) {
                foreach (var runner in group.tools) {
                    if (!runner.is_visible_in_catalog (Globals.SETTINGS))
                        continue;
                    table.add ({ get_runner_id (runner), runner.title });
                }
            }
            table.print (output);
        }

        private void on_progress_updated (Services.InstallJob job) {
            var speed = format_size ((int64) (job.speed_kbps * 1024));
            var progress = job.progress ?? "";

            string eta_text;
            if (job.seconds_remaining >= 0) {
                eta_text = _ ("ETA: %s").printf (format_time (job.seconds_remaining));
            } else {
                eta_text = _ ("ETA: --");
            }

            var label = job.state == Services.InstallJob.State.BUSY_UPDATING ? _ ("Updating") : _ ("Installing");

            output.info ("\r\033[2K%s %s... %s · %s (%s/s) [%s]\r", label, job.title, job.download_status, progress, speed, eta_text);
            output.flush_stdout ();
        }

        private string format_time (double seconds) {
            int total_seconds = (int) seconds;
            int h = total_seconds / 3600;
            int m = (total_seconds % 3600) / 60;
            int s = total_seconds % 60;

            if (h > 0) {
                return _ ("%dh %dm %ds").printf (h, m, s);
            } else if (m > 0) {
                return _ ("%dm %ds").printf (m, s);
            } else {
                return _ ("%ds").printf (s);
            }
        }
    }
}
