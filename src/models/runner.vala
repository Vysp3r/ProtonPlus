namespace ProtonPlus.Models {
	public abstract class Runner : Object {
		public string title { get; set; }
		public string description { get; set; }
		public Group group { get; set; }
		public bool has_more { get; set; }
		public bool has_latest_support { get; set; }
		public List<Release> releases;

		public abstract async List<Release> load ();

		public enum UpdateCodes {
			ERROR,
			NOTHING_FOUND,
			EVERYTHING_UPDATED
		}

		public static async UpdateCodes check_for_updates (List<Launcher> launchers) {
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
								break;
							}
						}
					}
				}
			}

			if (latest_runners.length () == 0)
				return UpdateCodes.NOTHING_FOUND;

			foreach (var runner in latest_runners) {
				var json = yield Utils.Web.GET (runner.endpoint + "?per_page=1", false);

				var root_node = Utils.Parser.get_node_from_json (json);
				if (root_node == null)
					return UpdateCodes.ERROR;

				if (root_node.get_node_type () != Json.NodeType.ARRAY)
					return UpdateCodes.ERROR;

				var root_array = root_node.get_array ();
				if (root_array == null)
					return UpdateCodes.ERROR;

				if (root_array.get_length () != 1)
					return UpdateCodes.ERROR;

				var object = root_array.get_object_element (0);

				var asset_array = object.get_array_member ("assets");
				if (asset_array == null)
					return UpdateCodes.ERROR;

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
					return UpdateCodes.ERROR;

				var base_runner_directory = "%s/%s".printf (runner.group.launcher.directory, runner.group.directory);

				var runner_directory = "%s/%s Latest".printf (base_runner_directory, runner.title);

				var version_content = Utils.Filesystem.get_file_content ("%s/version".printf (runner_directory));
				if (version_content == "")
					return UpdateCodes.ERROR;

				var current_title = version_content.split (" ")[1].strip ();
				if (title == current_title)
					continue;

				var backup_runner_directory = "%s/%s Latest Backup".printf (base_runner_directory, runner.title);

				var moved = yield Utils.Filesystem.move_directory (runner_directory, backup_runner_directory);
				if (!moved)
					return UpdateCodes.ERROR;

				var release = new Models.Releases.Latest (runner as Models.Runners.Basic, "%s Latest".printf (runner.title), description, release_date, download_url, page_url);

				var installed = yield release.install ();
				if (!installed) {
					var deleted = yield Utils.Filesystem.delete_directory (runner_directory);

					if (deleted)
						yield Utils.Filesystem.move_directory (backup_runner_directory, runner_directory);

					return UpdateCodes.ERROR;
				}

				var deleted = yield Utils.Filesystem.delete_directory (backup_runner_directory);
				if (!deleted)
					return UpdateCodes.ERROR;
			}

			return UpdateCodes.EVERYTHING_UPDATED;
		}
	}
}