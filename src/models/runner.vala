namespace ProtonPlus.Models {
	public abstract class Runner : Object {
		public string title { get; set; }
		public string description { get; set; }
		public Group group { get; set; }
		public bool has_more { get; set; }
		public bool has_latest_support { get; set; }
		public bool asset_position_hwcaps_condition { get; set; }
		public Utils.Web.GetType get_type { get; set; }
		public List<Release> releases;

		public abstract async ReturnCode load (out List<Release> releases);

		public static async ReturnCode check_for_updates (List<Launcher> launchers) {
			var latest_runners = new List<Models.Runners.Basic> ();

			foreach (var launcher in launchers) {
				foreach (var group in launcher.groups) {
					var directories = group.get_compatibility_tool_directories ();

					foreach (var runner in group.runners) {
						if (!runner.has_latest_support || !(runner is Models.Runners.Basic))
							continue;

						foreach (var directory in directories) {
							if (directory == "%s Latest".printf (runner.title)) {
								latest_runners.append (runner as Models.Runners.Basic);
								continue;
							}

							if (directory == "%s Latest Backup".printf (runner.title)) {
								var deleted_old_backup = yield Utils.Filesystem.delete_directory ("%s/%s/%s Latest Backup".printf (launcher.directory, group.directory, runner.title));
								if (!deleted_old_backup)
									return ReturnCode.UNKNOWN_ERROR;
								continue;
							}
						}
					}
				}
			}

			if (latest_runners.length () == 0)
				return ReturnCode.NOTHING_TO_UPDATE;

			var updated_count = 0;

			foreach (var runner in latest_runners) {
				var code = yield update_specific_runner (runner);
				if (code == ReturnCode.RUNNER_UPDATED)
					updated_count++;
				else
					return code;
			}

			return updated_count > 0 ? ReturnCode.RUNNERS_UPDATED : ReturnCode.NOTHING_TO_UPDATE;
		}

		public static async ReturnCode update_specific_runner (Models.Runners.Basic runner) {
			string? response;

			var code = yield Utils.Web.get_request ("%s?per_page=1".printf (runner.endpoint), runner.get_type, out response);

			if (code != ReturnCode.VALID_REQUEST)
				return code;
			
			var root_node = Utils.Parser.get_node_from_json (response);
			if (root_node == null)
				return ReturnCode.UNKNOWN_ERROR;

			if (root_node.get_node_type () != Json.NodeType.ARRAY)
				return ReturnCode.UNKNOWN_ERROR;

			var root_array = root_node.get_array ();
			if (root_array == null)
				return ReturnCode.UNKNOWN_ERROR;

			if (root_array.get_length () != 1)
				return ReturnCode.UNKNOWN_ERROR;

			var object = root_array.get_object_element (0);

			var asset_array = object.get_array_member ("assets");
			if (asset_array == null)
				return ReturnCode.UNKNOWN_ERROR;

			string title = object.get_string_member ("tag_name");
			string description = object.get_string_member ("body").strip ();
			string page_url = object.get_string_member ("html_url");
			string release_date = object.get_string_member ("created_at").split ("T")[0];
			string download_url = "";

			if (asset_array.get_length () - 1 >= runner.asset_position) {
				var asset_object = asset_array.get_object_element (runner.asset_position);

				download_url = asset_object.get_string_member ("browser_download_url");
			}

			if (download_url == "")
				return ReturnCode.UNKNOWN_ERROR;

			var base_runner_directory = "%s/%s".printf (runner.group.launcher.directory, runner.group.directory);

			var runner_directory = "%s/%s Latest".printf (base_runner_directory, runner.title);

			var version_content = Utils.Filesystem.get_file_content ("%s/version".printf (runner_directory));
			if (version_content == "")
				return ReturnCode.UNKNOWN_ERROR;

			var current_title = version_content.split (" ")[1].strip ();
			if (title == current_title)
				return ReturnCode.NOTHING_TO_UPDATE;

			var settings_path = "%s/user_settings.py".printf (runner_directory);
			var settings_exists = FileUtils.test (settings_path, FileTest.IS_REGULAR);
			var settings_content = "";
			if (settings_exists) {
				settings_content = Utils.Filesystem.get_file_content (settings_path);
			}

			var backup_runner_directory = "%s/%s Latest Backup".printf (base_runner_directory, runner.title);

			var moved = yield Utils.Filesystem.move_directory (runner_directory, backup_runner_directory);
			if (!moved)
				return ReturnCode.UNKNOWN_ERROR;

			var release = new Models.Releases.Latest (runner as Models.Runners.Basic, "%s Latest".printf (runner.title), description, release_date, download_url, page_url);

			var installed = yield release.install ();
			if (!installed) {
				var deleted = yield Utils.Filesystem.delete_directory (runner_directory);

				if (deleted)
					yield Utils.Filesystem.move_directory (backup_runner_directory, runner_directory);

				return ReturnCode.UNKNOWN_ERROR;
			}

			if (settings_exists) {
				Utils.Filesystem.create_file (settings_path, settings_content);
			}

			var deleted = yield Utils.Filesystem.delete_directory (backup_runner_directory);
			if (!deleted)
				return ReturnCode.UNKNOWN_ERROR;

			return ReturnCode.RUNNER_UPDATED;
		}
	}
}