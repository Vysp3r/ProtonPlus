namespace ProtonPlus.CLI {
    private const string CMD_VERSION = "version";
    private const string CMD_HELP = "help";
    private const string CMD_LIST = "list";
    private const string CMD_INSTALL = "install";
    private const string CMD_UNINSTALL = "uninstall";
    private const string CMD_UPDATE = "update";

    private const string OPT_LATEST = "latest";
    private const string OPT_ALL = "all";

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

            if (command != CMD_LIST && command != CMD_INSTALL &&
                command != CMD_UNINSTALL && command != CMD_UPDATE) {
                output.error (_ ("Error: Unknown command '%s'\n"), command);
                print_usage ();
                return 1;
            }

            if (command == CMD_INSTALL || command == CMD_UPDATE)
                progress_updated_handler_id = Utils.DownloadManager.instance.progress_updated.connect (on_progress_updated);
            if (command == CMD_INSTALL || command == CMD_UNINSTALL || command == CMD_UPDATE) {
                steam_restart_recording_failed_handler_id = Services.InstallationService.instance.steam_restart_recording_failed.connect ((job, message) => {
                    output.warning (_ ("Warning: %s\n"), message);
                });
            }

            try {
                if (!yield load_launchers ())
                    return 1;

                switch (command) {
                    case CMD_LIST:
                        return handle_list (args);
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
            if (args.length < 3) {
                output.header (_ ("Detected launchers:\n"));
                foreach (var launcher in launchers) {
                    output.info ("  %-45s (%s)\n", get_launcher_id (launcher), launcher.title);
                }
                return 0;
            }

            var launcher = find_launcher (args[2]);
            if (launcher == null) {
                return 1;
            }

            output.header (_ ("Installed runners for %s:\n"), launcher.title);
            var found = false;
            foreach (var group in launcher.groups) {
                group.refresh_installed_state ();
                var installed = group.get_installed_tool_snapshot ();
                var group_found = false;
                foreach (var entry in installed) {
                    // This was intentionally omitted by Group's former raw
                    // directory helper, so retain the CLI listing behavior.
                    if (entry.directory_name == "LegacyRuntime")
                        continue;
                    if (!group_found) {
                        output.info ("\n%s:\n", group.title);
                        group_found = true;
                    }
                    output.info ("  %s\n", entry.display_title);
                    found = true;
                }
            }
            if (!found) {
                output.warning (_ ("No runners installed\n"));
            }
            return 0;
        }

        private async int handle_install (string[] args) {
            if (!validate_args (args, 4, "protonplus install <launcher_id> <runner_id> [latest]")) {
                return 1;
            }

            var launcher = find_launcher (args[2]);
            if (launcher == null) {
                return 1;
            }

            var runner = find_runner (launcher, args[3]);
            if (runner == null) {
                return 1;
            }

            var provider_tool = get_provider_tool (runner, CMD_INSTALL);
            if (provider_tool == null) {
                return 1;
            }

            var use_latest = args.length >= 5 && args[4] == OPT_LATEST;
            return use_latest ? yield install_latest (provider_tool) : yield install_interactive (provider_tool);
        }

        private async int handle_uninstall (string[] args) {
            if (!validate_args (args, 4, "protonplus uninstall <launcher_id> <runner_id|all> [all]")) {
                return 1;
            }

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

            var provider_tool = get_provider_tool (runner, CMD_UNINSTALL);
            if (provider_tool == null) {
                return 1;
            }

            var uninstall_all = args.length >= 5 && args[4] == OPT_ALL;
            return uninstall_all ? yield uninstall_runner_all (provider_tool) : yield uninstall_interactive (provider_tool);
        }

        private async int handle_update (string[] args) {
            if (!validate_args (args, 3, "protonplus update <all|launcher_id> [runner_id]")) {
                return 1;
            }

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

                var provider_tool = get_provider_tool (runner, CMD_UPDATE);
                if (provider_tool == null) {
                    return 1;
                }
                return yield update_runner (provider_tool);
            }
            return yield update_launcher (launcher);
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
            for (var i = 0; i < catalog.releases.size; i++) {
                var release = catalog.releases[i] as Models.Release;
                output.info ("%d. %s (%s)\n", i + 1, release.title, release.release_date);
            }

            var index = read_user_selection (_ ("Select release number"), (int) catalog.releases.size);
            if (index < 0) {
                return 1;
            }

            var selected = catalog.releases[index] as Models.Release;
            output.info (_ ("Installing %s...\n"), selected.title);
            var job = create_install_job (selected, provider_tool);
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
            for (var i = 0; i < installed.size; i++) {
                output.info ("%d. %s\n", i + 1, installed[i].display_title);
            }

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
                output.error (_ ("Error: Uninstallation failed: %s\n"), get_return_code_message (code));
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

        private async int update_runner (Models.Tools.ProviderTool runner) {
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

        private Gee.LinkedList<Models.Tools.ProviderTool> collect_latest_runners (Gee.LinkedList<Models.Launcher> scope) {
            var latest_runners = new Gee.LinkedList<Models.Tools.ProviderTool> ();
            var collected_runner_ids = new Gee.HashSet<string> ();

            foreach (var launcher in scope) {
                foreach (var group in launcher.groups) {
                    group.refresh_installed_state ();
                    var entries = group.get_installed_tool_snapshot ();

                    foreach (var tool in group.tools) {
                        var provider_tool = tool as Models.Tools.ProviderTool;
                        if (provider_tool == null) {
                            continue;
                        }

                        foreach (var entry in entries) {
                            var latest = "%s Latest".printf (tool.title);
                            var backup = "%s Backup".printf (latest);
                            if (entry.directory_name == latest ||
                                entry.directory_name.has_prefix ("%s-".printf (latest)) ||
                                entry.directory_name == backup) {
                                if (collected_runner_ids.add (provider_tool.id))
                                    latest_runners.add (provider_tool);
                                continue;
                            }
                        }
                    }
                }
            }

            return latest_runners;
        }

        private async int update_runner_batch (Gee.LinkedList<Models.Tools.ProviderTool> runners) {
            if (runners.size == 0) {
                output.success (_ ("Already up to date\n"));
                return 0;
            }

            var failed = false;

            foreach (var runner in runners) {
                var code = yield update_runner_with_progress (runner);
                switch (code) {
                    case ReturnCode.RUNNER_UPDATED:
                        output.success (_ ("Successfully updated %s\n"), runner.title);
                        break;
                    case ReturnCode.NOTHING_TO_UPDATE:
                        output.success (_ ("Already up to date: %s\n"), runner.title);
                        break;
                    default:
                        output.error (_ ("Error: Failed to update %s: %s\n"), runner.title, get_return_code_message (code));
                        failed = true;
                        break;
                }
            }
            return failed ? 1 : 0;
        }

        private async ReturnCode update_runner_with_progress (Models.Tools.ProviderTool runner) {
            output.info (_ ("Updating %s...") + "\r", runner.title);
            output.flush_stdout ();

            var code = yield Services.InstallationService.instance.update_specific_runner (runner);

            output.info ("\r\033[2K\r");
            return code;
        }

        private async bool load_launchers () {
            if (fixture_launchers != null) {
                launchers = (!) fixture_launchers;
                return true;
            }
            var success = yield Models.Launcher.get_all (out launchers);
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

        private Models.Launcher? find_launcher (string launcher_id) {
            foreach (var launcher in launchers) {
                if (matches_launcher_id (launcher, launcher_id)) {
                    return launcher;
                }
            }
            output.error (_ ("Error: Launcher '%s' not found\n"), launcher_id);
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
                if (entry.provider_id == runner.provider_id &&
                    entry.tool_id == runner.id &&
                    entry.launcher_id == runner.group.launcher.tool_target_id)
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

        private bool validate_args (string[] args, int min_required, string usage) {
            if (args.length < min_required) {
                output.error (_ ("Usage: %s\n"), usage);
                return false;
            }
            return true;
        }

        private int read_user_selection (string prompt, int max) {
            output.info ("%s: ", prompt);
            output.flush_stdout ();
            var input = stdin.read_line ();

            if (input == null || input.strip () == "") {
                return -1;
            }

            var val = int.parse (input);
            if (val == 0 && input.strip () != "0") {
                output.error (_ ("Error: Invalid input, please enter a number\n"));
                return -1;
            }

            var index = val - 1;
            if (index < 0 || index >= max) {
                output.error (_ ("Error: Selection out of range\n"));
                return -1;
            }
            return index;
        }

        private void print_usage () {
            output.header (_ ("Usage:\n"));
            output.info ("  protonplus <command> [options]\n\n");
            output.header (_ ("Commands:\n"));
            output.info ("  %-45s %s\n", "version", _ ("Show version"));
            output.info ("  %-45s %s\n", "help", _ ("Show this help"));
            output.info ("  %-45s %s\n", "list [launcher_id]", _ ("List launchers or installed runners"));
            output.info ("  %-45s %s\n", "install <launcher_id> <runner_id> [latest]", _ ("Install runner"));
            output.info ("  %-45s %s\n", "uninstall <launcher_id> <runner_id|all> [all]", _ ("Uninstall runner"));
            output.info ("  %-45s %s\n", "update <all|launcher_id> [runner_id]", _ ("Update runner"));
        }

        private void print_available_launchers () {
            output.header (_ ("\nAvailable launchers:\n"));
            foreach (var launcher in launchers) {
                output.info ("  %-45s (%s)\n", get_launcher_id (launcher), launcher.title);
            }
        }

        private void print_available_runners (Models.Launcher launcher) {
            output.header (_ ("\nAvailable runners for %s:\n"), launcher.title);
            foreach (var group in launcher.groups) {
                foreach (var runner in group.tools) {
                    output.info ("  %-45s (%s)\n", get_runner_id (runner), runner.title);
                }
            }
        }

        private void on_progress_updated (Services.InstallJob job) {
            var speed = Utils.Filesystem.convert_download_speed_to_string ((int64) (job.speed_kbps * 1024));
            var progress = job.progress;

            string eta_text;
            if (job.seconds_remaining >= 0) {
                eta_text = _ ("ETA: %s").printf (format_time (job.seconds_remaining));
            } else {
                eta_text = _ ("ETA: --");
            }

            var label = job.state == Services.InstallJob.State.BUSY_UPDATING ? _ ("Updating") : _ ("Installing");

            output.info ("\r\033[2K%s %s... %s (%s/s) [%s]\r", label, job.title, progress, speed, eta_text);
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
