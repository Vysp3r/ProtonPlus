namespace ProtonPlus.Models {
    // A discovered local installation.  It deliberately contains no catalog,
    // network, GTK, or transaction behavior.
    public class InstalledToolEntry : Object {
        public string path { get; construct set; }
        public string directory_name { get; construct set; }
        public string internal_title { get; construct set; }
        public string display_title { get; construct set; }
        public string runner_endpoint { get; construct set; }
        public string runner_title { get; construct set; }
        public string tag { get; construct set; }
        public string provider_id { get; construct set; }
        public string tool_id { get; construct set; }
        public string launcher_id { get; construct set; }
        public string variant_id { get; construct set; }
        public string release_id { get; construct set; }
        public bool has_compatibilitytool_vdf { get; construct set; }

        public InstalledToolEntry (
            string path,
            string directory_name,
            string internal_title,
            string display_title,
            string runner_endpoint,
            string runner_title,
            string tag,
            string provider_id,
            string tool_id,
            string launcher_id,
            string variant_id,
            string release_id,
            bool has_compatibilitytool_vdf
        ) {
            Object (
                path: path,
                directory_name: directory_name,
                internal_title: internal_title,
                display_title: display_title,
                runner_endpoint: runner_endpoint,
                runner_title: runner_title,
                tag: tag,
                provider_id: provider_id,
                tool_id: tool_id,
                launcher_id: launcher_id,
                variant_id: variant_id,
                release_id: release_id,
                has_compatibilitytool_vdf: has_compatibilitytool_vdf
            );
        }

        public bool has_persisted_identity () {
            return provider_id != "" || tool_id != "" || launcher_id != "" ||
                   variant_id != "" || release_id != "";
        }

        public InstalledToolEntry with_stable_identity (string provider_id, string tool_id, string launcher_id) {
            return new InstalledToolEntry (
                path, directory_name, internal_title, display_title,
                runner_endpoint, runner_title, tag,
                provider_id, tool_id, launcher_id, variant_id, release_id,
                has_compatibilitytool_vdf
            );
        }
    }

    // Scoped to one Group so launcher roots, tool definitions, and cached
    // resolved state cannot leak into another launcher or category.
    public class InstalledToolInventory : Object {
        private Group group;
        private Gee.ArrayList<InstalledToolEntry> entries = new Gee.ArrayList<InstalledToolEntry> ();

        public bool is_stale { get; private set; default = true; }
        public uint refresh_generation { get; private set; default = 0; }

        public InstalledToolInventory (Group group) {
            this.group = group;
        }

        // Returns a defensive list copy.  Entries are construct-only data,
        // while the mutable cache stays private to this inventory.
        public Gee.List<InstalledToolEntry> get_snapshot () {
            var snapshot = new Gee.ArrayList<InstalledToolEntry> ();
            foreach (var entry in entries)
                snapshot.add (entry);
            return snapshot;
        }

        public void invalidate () {
            entries.clear ();
            is_stale = true;
            clear_tool_states ();
        }

        // The sole explicit operation that performs discovery, identity
        // resolution, legacy migration, and compatibility-tool usage checks.
        public void refresh () {
            entries.clear ();
            discover_entries ();
            resolve_entries ();
            is_stale = false;
            refresh_generation++;
        }

        private void discover_entries () {
            foreach (var directory_root in group.launcher.get_tool_directories (group)) {
                add_entry (directory_root);

                if (!FileUtils.test (directory_root, FileTest.IS_DIR))
                    continue;

                try {
                    var directory = File.new_for_path (directory_root);
                    FileEnumerator? enumerator = directory.enumerate_children ("standard::*", FileQueryInfoFlags.NONE, null);
                    if (enumerator == null)
                        continue;

                    FileInfo? file_info;
                    while ((file_info = enumerator.next_file ()) != null) {
                        if (file_info.get_file_type () != FileType.DIRECTORY)
                            continue;
                        add_entry (Path.build_filename (directory_root, file_info.get_name ()));
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }

        private void add_entry (string path) {
            var compatibilitytoolvdf_path = Path.build_filename (path, "compatibilitytool.vdf");
            var has_compatibilitytool_vdf = FileUtils.test (compatibilitytoolvdf_path, FileTest.IS_REGULAR);

            if (!has_compatibilitytool_vdf && !FileUtils.test (path, FileTest.IS_DIR))
                return;

            var directory_name = Path.get_basename (path);
            var internal_title = directory_name;
            var display_title = directory_name;
            if (has_compatibilitytool_vdf) {
                var compatibility_tool = Utils.VDF.CompatibilityToolLoader.from_path (path);
                internal_title = compatibility_tool.internal_title;
                display_title = compatibility_tool.display_title;
            }

            var metadata = Utils.Metadata.load (path);
            entries.add (new InstalledToolEntry (
                path, directory_name, internal_title, display_title,
                metadata.runner_endpoint, metadata.runner_title, metadata.tag,
                metadata.provider_id, metadata.tool_id, metadata.launcher_id,
                metadata.variant_id, metadata.release_id, has_compatibilitytool_vdf
            ));
        }

        private void resolve_entries () {
            clear_tool_states ();
            if (group.tools == null)
                return;

            foreach (var tool in group.tools) {
                var tinker_game = tool as Tools.TinkerGame;
                if (tinker_game != null) {
                    resolve_tinker_game (tool);
                    continue;
                }

                var provider_tool = tool as Tools.ProviderTool;
                if (provider_tool != null)
                    resolve_provider_tool (provider_tool);
            }
        }

        private void clear_tool_states () {
            if (group.tools == null)
                return;
            foreach (var tool in group.tools)
                tool.set_resolved_installation_state (null, null, false);
        }

        private void resolve_tinker_game (Tool tool) {
            foreach (var entry in entries) {
                if (entry.directory_name == "TinkerGame") {
                    set_tool_state (tool, entry, "Proton-tg");
                    return;
                }
            }
        }

        private void resolve_provider_tool (Tools.ProviderTool tool) {
            for (var index = 0; index < entries.size; index++) {
                var entry = entries[index];
                if (entry.has_persisted_identity () && persisted_identity_matches_tool (entry, tool)) {
                    set_tool_state (tool, entry, usage_identifier_for (entry));
                    return;
                }
            }

            for (var index = 0; index < entries.size; index++) {
                var entry = entries[index];
                if (entry.has_persisted_identity () || !legacy_metadata_matches_tool (entry, tool))
                    continue;
                if (!legacy_metadata_match_is_unambiguous (entry))
                    continue;

                var resolved_entry = migrate_legacy_identity (index, tool);
                // A failed migration leaves the legacy match usable, but does
                // not fabricate stable identity in the cached snapshot.
                set_tool_state (tool, resolved_entry, usage_identifier_for (resolved_entry));
                return;
            }

            foreach (var entry in entries) {
                if (!entry.has_persisted_identity () && identifier_matches_tool (entry.directory_name, tool)) {
                    set_tool_state (tool, entry, entry.directory_name);
                    return;
                }
            }

            foreach (var entry in entries) {
                if (entry.has_persisted_identity () || !entry.has_compatibilitytool_vdf)
                    continue;
                if (identifier_matches_tool (entry.internal_title, tool)) {
                    set_tool_state (tool, entry, usage_identifier_for (entry));
                    return;
                }
                if (identifier_matches_tool (entry.display_title, tool)) {
                    set_tool_state (tool, entry, usage_identifier_for (entry));
                    return;
                }
            }
        }

        private bool persisted_identity_matches_tool (InstalledToolEntry entry, Tools.ProviderTool tool) {
            if (entry.tool_id != "") {
                return entry.tool_id == tool.id &&
                       (entry.provider_id == "" || entry.provider_id == tool.provider_id) &&
                       (entry.launcher_id == "" || entry.launcher_id == group.launcher.tool_target_id);
            }

            return entry.provider_id != "" &&
                   entry.provider_id == tool.provider_id &&
                   (entry.launcher_id == "" || entry.launcher_id == group.launcher.tool_target_id);
        }

        private bool legacy_metadata_matches_tool (InstalledToolEntry entry, Tools.ProviderTool tool) {
            var endpoint_matches = entry.runner_endpoint != "" && entry.runner_endpoint == tool.endpoint;
            var title_matches = entry.runner_title != "" && entry.runner_title == tool.title;

            if (entry.runner_endpoint != "" && entry.runner_title != "")
                return endpoint_matches && title_matches;
            if (entry.runner_endpoint != "" || entry.runner_title != "")
                return endpoint_matches || title_matches;
            return legacy_tag_matches_tool (entry.tag, tool);
        }

        private bool legacy_tag_matches_tool (string tag, Tools.ProviderTool tool) {
            var catalog = tool.release_catalog;
            if (tag == "" || catalog == null)
                return false;
            foreach (var release in catalog.releases) {
                if (tag == release.title || tag == release.source_tag)
                    return true;
            }
            return false;
        }

        private bool legacy_metadata_match_is_unambiguous (InstalledToolEntry entry) {
            var matches = 0;
            foreach (var candidate in group.tools) {
                var provider_candidate = candidate as Tools.ProviderTool;
                if (provider_candidate != null && legacy_metadata_matches_tool (entry, provider_candidate))
                    matches++;
            }
            return matches == 1;
        }

        private InstalledToolEntry migrate_legacy_identity (int index, Tools.ProviderTool tool) {
            var entry = entries[index];
            var metadata = Utils.Metadata.load (entry.path);
            metadata.provider_id = tool.provider_id;
            metadata.tool_id = tool.id;
            metadata.launcher_id = group.launcher.tool_target_id;
            if (!metadata.save (entry.path))
                return entry;

            var migrated_entry = entry.with_stable_identity (
                tool.provider_id, tool.id, group.launcher.tool_target_id
            );
            entries[index] = migrated_entry;
            return migrated_entry;
        }

        private bool identifier_matches_tool (string identifier, Tools.ProviderTool tool) {
            if (identifier == "")
                return false;
            if (identifier == tool.title || identifier == "%s Latest".printf (tool.title))
                return true;
            var catalog = tool.release_catalog;
            if (catalog == null || catalog.releases.size == 0)
                return false;

            foreach (var release in catalog.releases) {
                var directory_name = tool.get_directory_name (release.title);
                if (identifier == directory_name)
                    return true;
                foreach (var variant in tool.variants) {
                    if (identifier == "%s%s".printf (directory_name, variant_directory_suffix (variant)))
                        return true;
                }
            }
            return false;
        }

        private string variant_directory_suffix (Variant variant) {
            if (variant.is_default)
                return "";
            return "-%s".printf (variant.name.replace (" ", "_").replace ("/", "_"));
        }

        private string usage_identifier_for (InstalledToolEntry entry) {
            if (!entry.has_compatibilitytool_vdf)
                return entry.directory_name;
            return entry.internal_title != "" ? entry.internal_title : entry.directory_name;
        }

        private void set_tool_state (Tool tool, InstalledToolEntry entry, string usage_identifier) {
            tool.set_resolved_installation_state (
                entry,
                usage_identifier,
                group.launcher.get_compatibility_tool_usage_count (usage_identifier) > 0
            );
        }
    }
}
