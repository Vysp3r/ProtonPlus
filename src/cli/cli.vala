namespace ProtonPlus.CLI {
	private const string CMD_VERSION = "version";
	private const string CMD_HELP = "help";
	private const string CMD_LIST = "list";
	private const string CMD_INSTALL = "install";
	private const string CMD_UNINSTALL = "uninstall";
	private const string CMD_UPDATE = "update";

	private const string OPT_LATEST = "latest";
	private const string OPT_ALL = "all";

	private class Output {
		public static void info (string format, ...) {
			var args = va_list ();
			print (format.vprintf (args));
		}

		public static void success (string format, ...) {
			var args = va_list ();
			print (format.vprintf (args));
		}

		public static void error (string format, ...) {
			var args = va_list ();
			printerr (format.vprintf (args));
		}
	}

	public class Handler {
		private List<Models.Launcher> launchers;

		public async int run (string[] args) {
			if (args.length < 2) {
				print_usage ();
				return 1;
			}

			yield Globals.load ();

			if (!yield load_launchers ()) {
				return 1;
			}

			var command = args[1];
			switch (command) {
				case CMD_VERSION:
					Output.info ("ProtonPlus %s\n", Config.APP_VERSION);
					return 0;
				case CMD_HELP:
					print_usage ();
					return 0;
				case CMD_LIST:
					return handle_list (args);
				case CMD_INSTALL:
					return yield handle_install (args);
				case CMD_UNINSTALL:
					return yield handle_uninstall (args);
				case CMD_UPDATE:
					return yield handle_update (args);
				default:
					Output.error (_("Error: Unknown command '%s'\n"), command);
					print_usage ();
					return 1;
			}
		}

		private int handle_list (string[] args) {
			if (args.length < 3) {
				Output.info (_("Detected launchers:\n"));
				foreach (var launcher in launchers) {
					Output.info ("  %s (%s)\n", get_launcher_id (launcher), launcher.title);
				}
				return 0;
			}

			var launcher = find_launcher (args[2]);
			if (launcher == null) {
				return 1;
			}

			Output.info (_("Installed runners for %s:\n"), launcher.title);
			var found = false;
			foreach (var group in launcher.groups) {
				var installed = group.get_compatibility_tool_directories ();
				if (installed.length () > 0) {
					Output.info ("\n%s:\n", group.title);
					foreach (var dir in installed) {
						Output.info ("  %s\n", dir);
						found = true;
					}
				}
			}
			if (!found) {
				Output.info (_("No runners installed\n"));
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

			var use_latest = args.length >= 5 && args[4] == OPT_LATEST;
			return use_latest ? yield install_latest (runner) : yield install_interactive (runner);
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

			var uninstall_all = args.length >= 5 && args[4] == OPT_ALL;
			return uninstall_all ? yield uninstall_runner_all (runner) : yield uninstall_interactive (runner);
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
				return yield update_runner (runner);
			}
			return yield update_launcher (launcher);
		}

		private async int install_latest (Models.Runner runner) {
			if (!runner.has_latest_support) {
				Output.error (_("Error: Runner '%s' does not support 'latest' installation\n"), runner.title);
				return 1;
			}

			var basic_runner = runner as Models.Runners.Basic;
			var code = yield load_runner_releases (basic_runner);
			if (code != ReturnCode.RELEASES_LOADED || basic_runner.releases.length () == 0) {
				return 1;
			}

			var release = basic_runner.releases.nth_data (0) as Models.Releases.Basic;
			var latest_release = new Models.Releases.Latest (
				basic_runner,
				"%s Latest".printf (runner.title),
				release.description,
				release.release_date,
				release.download_url,
				release.page_url
			);

			Output.info (_("Installing %s Latest...\n"), runner.title);
			var success = yield latest_release.install ();
			Output.success (success ? _("Successfully installed %s Latest\n") : _("Error: Installation failed\n"), runner.title);
			return success ? 0 : 1;
		}

		private async int install_interactive (Models.Runner runner) {
			var basic_runner = runner as Models.Runners.Basic;
			var code = yield load_runner_releases (basic_runner);
			if (code != ReturnCode.RELEASES_LOADED || basic_runner.releases.length () == 0) {
				return 1;
			}

			Output.info (_("Available releases for %s:\n"), runner.title);
			for (var i = 0; i < basic_runner.releases.length (); i++) {
				var release = basic_runner.releases.nth_data (i) as Models.Releases.Basic;
				Output.info ("%d. %s (%s)\n", i + 1, release.title, release.release_date);
			}

			var index = read_user_selection ("Select release number", (int) basic_runner.releases.length ());
			if (index < 0) {
				return 1;
			}

			var selected = basic_runner.releases.nth_data (index) as Models.Releases.Basic;
			Output.info (_("Installing %s...\n"), selected.title);
			var success = yield selected.install ();
			Output.success (success ? _("Successfully installed %s\n") : _("Error: Installation failed\n"), selected.title);
			return success ? 0 : 1;
		}

		private async int uninstall_interactive (Models.Runner runner) {
			var installed = get_installed_releases (runner);
			if (installed.length () == 0) {
				Output.info (_("No installed releases found for %s\n"), runner.title);
				return 0;
			}

			Output.info (_("Installed releases for %s:\n"), runner.title);
			for (var i = 0; i < installed.length (); i++) {
				Output.info ("%d. %s\n", i + 1, installed.nth_data (i));
			}

			var index = read_user_selection (_("Select release number"), (int) installed.length ());
			if (index < 0) {
				return 1;
			}

			var release_name = installed.nth_data (index);
			return yield uninstall_single_release (runner, release_name);
		}

		private async int uninstall_runner_all (Models.Runner runner) {
			var installed = get_installed_releases (runner);
			if (installed.length () == 0) {
				Output.info (_("No installed releases found for %s\n"), runner.title);
				return 0;
			}

			Output.info (_("Uninstalling all releases for %s...\n"), runner.title);
			foreach (var release_name in installed) {
				yield uninstall_single_release (runner, release_name);
			}
			return 0;
		}

		private async int uninstall_launcher_all (Models.Launcher launcher) {
			Output.info (_("Uninstalling all releases for launcher %s...\n"), launcher.title);
			foreach (var group in launcher.groups) {
				foreach (var runner in group.runners) {
					var installed = get_installed_releases (runner);
					foreach (var release_name in installed) {
						var release = create_release (runner, release_name);
						if (yield release.remove (new Models.Parameters ())) {
							Output.success (_("Uninstalled %s\n"), release_name);
						}
					}
				}
			}
			return 0;
		}

		private async int uninstall_single_release (Models.Runner runner, string release_name) {
			var release = create_release (runner, release_name);
			Output.info (_("Uninstalling %s...\n"), release_name);
			var success = yield release.remove (new Models.Parameters ());
			Output.success (success ? _("Successfully uninstalled %s\n") : _("Error: Uninstallation failed\n"), release_name);
			return success ? 0 : 1;
		}

		private async int update_all () {
			Output.info (_("Updating all runners...\n"));
			var latest_runners = yield collect_latest_runners (launchers);
			return yield update_runner_batch (latest_runners);
		}

		private async int update_launcher (Models.Launcher launcher) {
			Output.info (_("Updating runners for %s...\n"), launcher.title);
			var scoped = new List<Models.Launcher> ();
			scoped.append (launcher);
			var latest_runners = yield collect_latest_runners (scoped);
			return yield update_runner_batch (latest_runners);
		}

		private async int update_runner (Models.Runner runner) {
			if (!runner.has_latest_support) {
				return 1;
			}

			var code = yield update_runner_with_progress (runner as Models.Runners.Basic);
			switch (code) {
				case ReturnCode.RUNNER_UPDATED:
					Output.success (_("Successfully updated %s\n"), runner.title);
					return 0;
				case ReturnCode.NOTHING_TO_UPDATE:
					Output.success (_("Already up to date: %s\n"), runner.title);
					return 0;
				default:
					Output.error (_("Error: Failed to update %s\n"), runner.title);
					return 1;
			}
		}

		private async List<Models.Runners.Basic> collect_latest_runners (List<Models.Launcher> scope) {
			var latest_runners = new List<Models.Runners.Basic> ();

			foreach (var launcher in scope) {
				foreach (var group in launcher.groups) {
					var directories = group.get_compatibility_tool_directories ();

					foreach (var runner in group.runners) {
						if (!runner.has_latest_support || !(runner is Models.Runners.Basic)) {
							continue;
						}

						foreach (var directory in directories) {
							if (directory == "%s Latest".printf (runner.title)) {
								latest_runners.append (runner as Models.Runners.Basic);
								continue;
							}

							if (directory == "%s Latest Backup".printf (runner.title)) {
								yield Utils.Filesystem.delete_directory (
									"%s/%s/%s Latest Backup".printf (launcher.directory, group.directory, runner.title)
								);
								continue;
							}
						}
					}
				}
			}

			return latest_runners;
		}

		private async int update_runner_batch (List<Models.Runners.Basic> runners) {
			if (runners.length () == 0) {
				Output.success (_("Already up to date\n"));
				return 0;
			}

			var updated_count = 0;

			foreach (var runner in runners) {
				var code = yield update_runner_with_progress (runner);
				switch (code) {
					case ReturnCode.RUNNER_UPDATED:
						Output.success (_("Successfully updated %s\n"), runner.title);
						updated_count++;
						break;
					case ReturnCode.NOTHING_TO_UPDATE:
						Output.success (_("Already up to date: %s\n"), runner.title);
						break;
					default:
						Output.error (_("Error: Failed to update %s\n"), runner.title);
						break;
				}
			}
			return 0;
		}

		private async ReturnCode update_runner_with_progress (Models.Runners.Basic runner) {
			Output.info (_("Updating %s...") + "\r", runner.title);
			stdout.flush ();

			var code = yield Models.Runner.update_specific_runner (runner);

			Output.info ("\r\033[2K\r");
			return code;
		}

		private async bool load_launchers () {
			var success = yield Models.Launcher.get_all (out launchers);
			if (!success || launchers == null) {
				Output.error (_("Error: Failed to load launchers\n"));
				return false;
			}
			return true;
		}

		private async ReturnCode load_runner_releases (Models.Runners.Basic basic_runner) {
			var code = yield basic_runner.load (out basic_runner.releases);
			if (code != ReturnCode.RELEASES_LOADED || basic_runner.releases.length () == 0) {
				Output.error (_("Error: Failed to load releases\n"));
			}
			return code;
		}

		private Models.Launcher? find_launcher (string launcher_id) {
			foreach (var launcher in launchers) {
				if (get_launcher_id (launcher) == launcher_id) {
					return launcher;
				}
			}
			Output.error (_("Error: Launcher '%s' not found\n"), launcher_id);
			print_available_launchers ();
			return null;
		}

		private Models.Runner? find_runner (Models.Launcher launcher, string runner_id) {
			foreach (var group in launcher.groups) {
				foreach (var runner in group.runners) {
					if (get_runner_id (runner) == runner_id) {
						return runner;
					}
				}
			}
			Output.error (_("Error: Runner '%s' not found\n"), runner_id);
			print_available_runners (launcher);
			return null;
		}

		private List<string> get_installed_releases (Models.Runner runner) {
			var directories = runner.group.get_compatibility_tool_directories ();
			var installed = new List<string> ();

			foreach (var dir in directories) {
				if (dir.has_prefix (runner.title)) {
					installed.append (dir);
				}
			}
			return installed;
		}

		private string get_launcher_id (Models.Launcher launcher) {
			return "%s-%s".printf (launcher.title.down ().replace (" ", "-"), launcher.get_installation_type_title ().down ());
		}

		private string get_runner_id (Models.Runner runner) {
			return runner.title.down ().replace (" ", "-");
		}

		private string get_release_path (Models.Runner runner, string release_name) {
			return "%s%s/%s".printf (runner.group.launcher.directory, runner.group.directory, release_name);
		}

		private Models.Releases.Basic create_release (Models.Runner runner, string release_name) {
			return new Models.Releases.Basic.simple (
				runner as Models.Runners.Basic,
				release_name,
				get_release_path (runner, release_name)
			);
		}

		private bool validate_args (string[] args, int min_required, string usage) {
			if (args.length < min_required) {
				Output.error (_("Usage: %s\n"), usage);
				return false;
			}
			return true;
		}

		private int read_user_selection (string prompt, int max) {
			stdout.printf ("%s: ", prompt);
			stdout.flush ();
			var input = stdin.read_line ();
			var index = int.parse (input) - 1;
			if (index < 0 || index >= max) {
				Output.error (_("Error: Invalid selection\n"));
				return -1;
			}
			return index;
		}

		private void print_usage () {
			Output.info (_("Usage: protonplus <command> [options]\n\n"));
			Output.info (_("Commands:\n"));
			Output.info ("  version                                        " + _("Show version\n"));
			Output.info ("  help                                           " + _("Show this help\n"));
			Output.info ("  list [launcher_id]                             " + _("List launchers or installed runners\n"));
			Output.info ("  install <launcher_id> <runner_id> [latest]     " + _("Install runner\n"));
			Output.info ("  uninstall <launcher_id> <runner_id|all> [all]  " + _("Uninstall runner\n"));
			Output.info ("  update <all|launcher_id> [runner_id]           " + _("Update runner\n"));
		}

		private void print_available_launchers () {
			Output.info (_("\nAvailable launchers:\n"));
			foreach (var launcher in launchers) {
				Output.info ("  %s\n", get_launcher_id (launcher));
			}
		}

		private void print_available_runners (Models.Launcher launcher) {
			Output.info (_("\nAvailable runners for %s:\n"), launcher.title);
			foreach (var group in launcher.groups) {
				foreach (var runner in group.runners) {
					Output.info ("  %s\n", get_runner_id (runner));
				}
			}
		}
	}
}
