namespace ProtonPlus.Models.Launchers {
    public class Lutris : Launcher {
        public const string FAMILY_ID = "lutris";

        internal Services.LutrisConfigurationService configuration { get; private set; }
        private Services.LutrisPaths? paths;
        private string? path_error;
        public string? library_error { get; private set; }
        public override string? game_library_error { get { return library_error; } }
        public override bool load_library_on_startup { get { return false; } }
        public override bool supports_bulk_game_edit { get { return false; } }

        public Lutris (Launcher.InstallationTypes installation_type,
            Services.LutrisConfigurationService? configuration = null) {
            base ("Lutris", installation_type, "%s/lutris.svg".printf (Config.RESOURCE_BASE), {}, FAMILY_ID);
            this.configuration = configuration ??
                Services.LutrisConfigurationService.for_installation (installation_type == InstallationTypes.FLATPAK);
            has_library_support = installation_type != InstallationTypes.SNAP;
            if (!has_library_support)
                return;

            directory = this.configuration.data;
            installed = FileUtils.test (directory, FileTest.IS_DIR) ||
                FileUtils.test (this.configuration.legacy_config, FileTest.IS_DIR) ||
                FileUtils.test (this.configuration.previous_data, FileTest.IS_DIR);
            try {
                paths = this.configuration.resolve_paths ();
                installed = installed || FileUtils.test (paths.database, FileTest.EXISTS);
            } catch (Error error) {
                path_error = error.message;
            }
        }

        private static string tool_directory (Services.LutrisPaths paths, string group_id) {
            // Both Lutris versions search WINE_DIR for Proton, even when the
            // launcher also discovers host Steam builds.
            return group_id == "dxvk" || group_id == "vkd3d"
                ? Path.build_filename (paths.runtime, group_id) : paths.wine;
        }

        public override string get_primary_managed_tool_directory (Group group) {
            return paths != null ? tool_directory (paths, group.id) : base.get_primary_managed_tool_directory (group);
        }

        public override List<string> get_managed_tool_directories (Group group) {
            var result = new List<string> ();
            var seen = new Gee.HashSet<string> ();
            var primary = get_primary_managed_tool_directory (group);
            foreach (var root in new string[] { primary, directory + group.directory,
                configuration.previous_data + group.directory }) {
                if (seen.add (Posix.realpath (root) ?? Filename.canonicalize (root)))
                    result.append (root);
            }
            return result;
        }

        internal bool owns_tool_storage_entry (Group group, string root, string owner) {
            if (owner != "")
                return owner == tool_target_id;
            // A redirected root shared with another launcher can contain
            // unmanaged builds. Only infer legacy ownership in old Lutris roots.
            return !shared_tool_roots.contains (root) ||
                root == physical_tool_path (directory + group.directory) ||
                root == physical_tool_path (configuration.previous_data + group.directory);
        }

        internal async string? validate_tool_destination (Group group) {
            string? failure = path_error;
            var primary = get_primary_managed_tool_directory (group);
            SourceFunc resume = validate_tool_destination.callback;
            new Thread<void> ("lutris-paths", () => {
                try {
                    var current = tool_directory (configuration.resolve_paths (), group.id);
                    if (physical_tool_path (current) != physical_tool_path (primary))
                        failure = _("Lutris tool directories changed. Restart ProtonPlus and try again.");
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            return failure;
        }

        public override async bool ensure_group_directory (string group_directory) {
            if (paths == null)
                return false;
            var target = group_directory.has_prefix ("/runtime/")
                ? Path.build_filename (paths.runtime, Path.get_basename (group_directory)) : paths.wine;
            return yield Utils.Filesystem.create_directory_async (target);
        }

        public override async bool load_game_library () {
            Gee.List<Services.LutrisGameRecord>? records = null;
            Gee.List<CompatibilityTool>? choices = null;
            bool probe_failed = false;
            string? failure = null;
            SourceFunc resume = load_game_library.callback;
            new Thread<void> ("lutris-library", () => {
                try {
                    records = configuration.read_library ();
                    if (records.any_match ((record) => record.runner == "wine" && record.config != null)) {
                        try {
                            choices = configuration.installed_runners ();
                        } catch (Error error) {
                            probe_failed = true;
                            debug ("Could not read Lutris runners: %s", error.message);
                        }
                    }
                } catch (Error error) {
                    failure = error.message;
                }
                Idle.add ((owned) resume);
            });
            yield;
            library_error = failure;
            if (records == null)
                return false;
            var discovered = new List<Game> ();
            foreach (var record in records)
                discovered.append (new Games.Lutris (record, this, configuration, choices, probe_failed));
            games = (owned) discovered;
            return true;
        }
    }
}
