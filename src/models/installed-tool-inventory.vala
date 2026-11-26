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
        public string install_mode { get; construct set; }
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
            bool has_compatibilitytool_vdf,
            string install_mode = ""
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
                install_mode: install_mode,
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
                has_compatibilitytool_vdf, install_mode
            );
        }
    }

    // Scoped to one Group so launcher roots, tool definitions, and cached
    // resolved state cannot leak into another launcher or category.
    public class InstalledToolInventory : Object {
        private Group group;
        private Gee.ArrayList<InstalledToolEntry> entries = new Gee.ArrayList<InstalledToolEntry> ();
        private Gee.HashSet<string> linked_directory_names = new Gee.HashSet<string> ();

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

        // Resolve every recorded release, not just the one used for a tool's
        // installed-state projection. This is a cached, read-only lookup: bare
        // directory/VDF names are not evidence of a ProtonPlus installation.
        public Tools.ProviderTool? get_provider_tool_for_entry (InstalledToolEntry entry) {
            if (group.tools == null)
                return null;

            foreach (var candidate in group.tools) {
                var tool = candidate as Tools.ProviderTool;
                if (tool == null)
                    continue;
                if (entry.has_persisted_identity ()) {
                    if (persisted_identity_matches_tool (entry, tool))
                        return tool;
                } else if (legacy_metadata_matches_tool (entry, tool) &&
                           legacy_metadata_match_is_unambiguous (entry)) {
                    return tool;
                }
            }
            return null;
        }

        // Includes legacy installs whose exact layout identifies one tool.
        // Stable receipts still take precedence over names on disk.
        public Gee.List<InstalledToolEntry> get_installations_for_tool (Tool tool) {
            var result = new Gee.ArrayList<InstalledToolEntry> ();
            var provider = tool as Tools.ProviderTool;
            if (provider == null) {
                if (tool.resolved_installed_entry != null)
                    result.add ((!) tool.resolved_installed_entry);
                return result;
            }

            foreach (var entry in entries) {
                if (is_latest_installation (entry, provider, true))
                    continue;
                var owner = get_provider_tool_for_entry (entry);
                if (owner == null && !entry.has_persisted_identity () &&
                    entry.runner_endpoint == "" && entry.runner_title == "" && entry.tag == "")
                    owner = get_legacy_layout_owner (entry);
                if (owner == provider)
                    result.add (entry);
            }
            result.sort ((left, right) => strcmp (left.directory_name, right.directory_name));
            return result;
        }

        private Tools.ProviderTool? get_legacy_layout_owner (InstalledToolEntry entry) {
            if (group.tools == null)
                return null;
            foreach (var directory_root in group.launcher.get_managed_tool_directories (group))
                if (entry.path == directory_root)
                    return null;

            Tools.ProviderTool? owner = null;
            foreach (var candidate in group.tools) {
                var provider = candidate as Tools.ProviderTool;
                if (provider == null || !identifier_matches_tool (entry.directory_name, provider))
                    continue;
                if (owner != null)
                    return null;
                owner = provider;
            }
            return owner;
        }

        internal InstalledToolEntry? find_versioned_installation (Tools.ProviderTool tool, Release release, Variant? variant) {
            var canonical = Path.build_filename (group.launcher.get_primary_managed_tool_directory (group),
                tool.get_directory_name (release.title, variant));
            var variant_id = variant?.id ?? tool.variants.first_match ((candidate) => candidate.is_default)?.id;
            var releases = new Gee.ArrayList<Release> ();
            releases.add (release);
            InstalledToolEntry? found = null;
            int matches = 0;
            foreach (var entry in get_installations_for_tool (tool)) {
                if (is_latest_installation (entry, tool) ||
                    find_installed_release (tool, entry, releases) == null ||
                    find_installed_variant (tool, entry, release)?.id != variant_id)
                    continue;
                if (entry.path == canonical)
                    return entry;
                found = entry;
                matches++;
            }
            return matches == 1 ? found : null;
        }

        public Release? find_installed_release (Tool tool, InstalledToolEntry entry,
            Gee.Iterable<Release>? releases = null) {
            var candidates = releases ?? tool.release_catalog?.releases;
            if (candidates == null)
                return null;

            var provider = tool as Tools.ProviderTool;
            Release? match = null;
            foreach (var release in candidates) {
                bool matched;
                if (entry.release_id != "")
                    matched = entry.release_id == release.upstream_release_id;
                else if (entry.tag != "")
                    matched = entry.tag == release.source_tag || entry.tag == release.title;
                else {
                    var variant = provider != null ? find_installed_variant (provider, entry, release) : null;
                    matched = variant != null && provider != null &&
                        entry.directory_name == provider.get_directory_name (release.title, variant);
                }
                if (!matched)
                    continue;
                if (match != null)
                    return null;
                match = release;
            }
            return match;
        }

        public Variant? find_installed_variant (Tools.ProviderTool tool, InstalledToolEntry entry, Release? release) {
            if (entry.variant_id != "") {
                if (release != null)
                    foreach (var variant in release.variants)
                        if (variant.id == entry.variant_id)
                            return variant;
                foreach (var variant in tool.variants)
                    if (variant.id == entry.variant_id)
                        return variant;
                return null;
            }

            if (is_latest_installation (entry, tool))
                return get_latest_variant (entry, tool);
            if (release == null)
                return null;

            Variant? match = null;
            foreach (var variant in release.variants) {
                if (entry.directory_name != tool.get_directory_name (release.title, variant))
                    continue;
                if (match != null)
                    return null;
                match = variant;
            }
            return match;
        }

        // Pure cached lookup for consumers that already know the physical
        // installation target.  This deliberately performs no discovery or
        // manifest parsing.
        public string? get_usage_identifier_for_path (string path) {
            var entry = get_installation_for_path (path);
            return entry != null ? usage_identifier_for (entry) : null;
        }

        public InstalledToolEntry? get_installation_for_path (string path) {
            if (path == "")
                return null;

            var target_path = Filename.canonicalize (path, null);
            foreach (var entry in entries) {
                if (Filename.canonicalize (entry.path, null) == target_path)
                    return entry;
            }
            return null;
        }

        // Latest is an installation slot, independent of the current display
        // title. All consumers share this cached ownership/mode decision.
        public bool is_latest_installation (InstalledToolEntry entry, Tools.ProviderTool tool, bool backup = false) {
            if (tool.definition.managed_steam_manifest)
                return !backup && entry.install_mode == "latest" && persisted_identity_matches_tool (entry, tool);

            if (entry.has_persisted_identity ()) {
                if (!persisted_identity_matches_tool (entry, tool))
                    return false;
            } else if (entry.runner_endpoint != "" || entry.runner_title != "") {
                if (!legacy_metadata_matches_tool (entry, tool) || !legacy_metadata_match_is_unambiguous (entry))
                    return false;
            }

            if (entry.install_mode != "" && entry.install_mode != "latest")
                return false;
            if (backup != entry.directory_name.has_suffix (" Backup"))
                return false;
            if (!backup && entry.install_mode == "latest" && entry.has_persisted_identity ())
                return true;

            var name = backup
                ? entry.directory_name.substring (0, entry.directory_name.length - " Backup".length)
                : entry.directory_name;
            foreach (var title in latest_titles (entry, tool)) {
                var latest = "%s Latest".printf (title);
                if (name == latest || (entry.variant_id != "" && name.has_prefix (latest + "-")))
                    return true;
                foreach (var variant in tool.variants)
                    if (name == tool.get_directory_name (latest, variant))
                        return true;
            }
            return false;
        }

        public Variant? get_latest_variant (InstalledToolEntry entry, Tools.ProviderTool tool) {
            foreach (var variant in tool.variants) {
                if (entry.variant_id != "") {
                    if (entry.variant_id == variant.id)
                        return variant;
                    continue;
                }
                foreach (var title in latest_titles (entry, tool)) {
                    var name = tool.get_directory_name ("%s Latest".printf (title), variant);
                    if (entry.directory_name == name || entry.directory_name == "%s Backup".printf (name))
                        return variant;
                }
            }
            return null;
        }

        internal bool has_linked_latest_installation (Tools.ProviderTool tool) {
            if (linked_directory_names.is_empty)
                return false;
            if (has_linked_latest_slot (tool, tool.title))
                return true;
            foreach (var title in tool.definition.legacy_titles)
                if (has_linked_latest_slot (tool, title))
                    return true;
            return false;
        }

        private bool has_linked_latest_slot (Tools.ProviderTool tool, string title) {
            var latest = "%s Latest".printf (title);
            foreach (var variant in tool.variants)
                if (linked_directory_names.contains (tool.get_directory_name (latest, variant)))
                    return true;
            return false;
        }

        public InstalledToolEntry? get_latest_installation (
            Tools.ProviderTool tool, Variant? variant = null, bool backup = false
        ) {
            if (variant == null) {
                foreach (var candidate in tool.variants) {
                    if (candidate.is_default) {
                        variant = candidate;
                        break;
                    }
                }
            }
            if (variant == null)
                return null;

            InstalledToolEntry? found = null;
            var matches = 0;
            var canonical = Path.build_filename (group.launcher.get_primary_managed_tool_directory (group),
                tool.get_directory_name ("%s Latest".printf (tool.title), variant) + (backup ? " Backup" : ""));
            foreach (var entry in entries) {
                if (!is_latest_installation (entry, tool, backup))
                    continue;
                var installed_variant = get_latest_variant (entry, tool);
                if (installed_variant == null || installed_variant.id != variant.id)
                    continue;
                if (entry.path == canonical)
                    return entry;
                found = entry;
                matches++;
            }
            // Multiple old slots must not select an arbitrary removal target.
            return matches == 1 ? found : null;
        }

        private string[] latest_titles (InstalledToolEntry entry, Tools.ProviderTool tool) {
            var titles = new Gee.ArrayList<string> ();
            titles.add (tool.title);
            titles.add_all_array (tool.definition.legacy_titles);
            if (entry.runner_title != "" && entry.has_persisted_identity () && persisted_identity_matches_tool (entry, tool))
                titles.add (entry.runner_title);
            return titles.to_array ();
        }

        public void invalidate () {
            entries.clear ();
            linked_directory_names.clear ();
            is_stale = true;
            clear_tool_states ();
        }

        // Read-only callers can resolve legacy receipts without rewriting them.
        public void refresh (bool migrate_legacy_metadata = true) {
            entries.clear ();
            linked_directory_names.clear ();
            discover_entries ();
            resolve_entries (migrate_legacy_metadata);
            is_stale = false;
            refresh_generation++;
        }

        private void discover_entries () {
            foreach (var directory_root in group.launcher.get_managed_tool_directories (group)) {
                Posix.Stat root_stat;
                if (Posix.lstat (directory_root, out root_stat) != 0 ||
                    (!Posix.S_ISDIR (root_stat.st_mode) && !FileUtils.test (directory_root, FileTest.IS_DIR)))
                    continue;

                try {
                    var directory = File.new_for_path (directory_root);
                    // A launcher can relocate its collection with a symlink.
                    // Only real child directories count as installations there.
                    if (Posix.S_ISDIR (root_stat.st_mode))
                        add_entry (directory_root);

                    FileEnumerator? enumerator = directory.enumerate_children (
                        "standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null
                    );
                    if (enumerator == null)
                        continue;

                    FileInfo? file_info;
                    while ((file_info = enumerator.next_file ()) != null) {
                        if (file_info.get_file_type () == FileType.DIRECTORY)
                            add_entry (Path.build_filename (directory_root, file_info.get_name ()));
                        else if (file_info.get_file_type () == FileType.SYMBOLIC_LINK)
                            linked_directory_names.add (file_info.get_name ());
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
            var lutris = group.launcher as Launchers.Lutris;
            if (lutris != null && !lutris.owns_tool_storage_entry (
                group, Launcher.physical_tool_path (Path.get_dirname (path)), metadata.launcher_id))
                return;
            entries.add (new InstalledToolEntry (
                path, directory_name, internal_title, display_title,
                metadata.runner_endpoint, metadata.runner_title, metadata.tag,
                metadata.provider_id, metadata.tool_id, metadata.launcher_id,
                metadata.variant_id, metadata.release_id, has_compatibilitytool_vdf, metadata.install_mode
            ));
        }

        private void resolve_entries (bool migrate_legacy_metadata) {
            clear_tool_states ();
            if (group.tools == null)
                return;

            foreach (var tool in group.tools) {
                if (tool is Tools.TinkerGame) {
                    foreach (var entry in entries) {
                        if (entry.directory_name == "TinkerGame" && entry.internal_title == "Proton-tg") {
                            set_tool_state (tool, entry, "Proton-tg");
                            break;
                        }
                    }
                    continue;
                }
                var steam_tinker_launch = tool as Tools.SteamTinkerLaunch;
                if (steam_tinker_launch != null) {
                    resolve_steam_tinker_launch (tool);
                    continue;
                }

                var provider_tool = tool as Tools.ProviderTool;
                if (provider_tool != null)
                    resolve_provider_tool (provider_tool, migrate_legacy_metadata);
            }
        }

        private void clear_tool_states () {
            if (group.tools == null)
                return;
            foreach (var tool in group.tools)
                tool.set_resolved_installation_state (null, null, false);
        }

        private void resolve_steam_tinker_launch (Tool tool) {
            foreach (var entry in entries) {
                if (entry.directory_name == "SteamTinkerLaunch") {
                    set_tool_state (tool, entry, "Proton-stl");
                    return;
                }
            }
        }

        private void resolve_provider_tool (Tools.ProviderTool tool, bool migrate_legacy_metadata) {
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

                var resolved_entry = migrate_legacy_metadata ? migrate_legacy_identity (index, tool) : entry;
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
            if (tool.definition.managed_steam_manifest)
                return matches_managed_identity (tool, entry.provider_id, entry.tool_id, entry.launcher_id);

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
            if (tool.definition.managed_steam_manifest)
                return false;

            var endpoint_matches = tool.definition.matches_endpoint (entry.runner_endpoint);
            var title_matches = tool.definition.matches_title (entry.runner_title);

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
            if (group.tools == null)
                return false;
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
            if (identifier == "" || tool.definition.managed_steam_manifest)
                return false;
            if (tool.definition.matches_title (identifier))
                return true;
            var titles = new Gee.ArrayList<string> ();
            titles.add (tool.title);
            titles.add_all_array (tool.definition.legacy_titles);
            foreach (var title in titles) {
                foreach (var variant in tool.variants) {
                    if (identifier == tool.get_directory_name ("%s Latest".printf (title), variant))
                        return true;
                }
            }
            var catalog = tool.release_catalog;
            if (catalog == null || catalog.releases.size == 0)
                return false;

            foreach (var release in catalog.releases) {
                var directory_name = tool.get_directory_name (release.title);
                if (identifier == directory_name)
                    return true;
                foreach (var variant in tool.variants) {
                    if (identifier == tool.get_directory_name (release.title, variant))
                        return true;
                }
            }
            return false;
        }

        private static bool matches_managed_identity (
            Tools.ProviderTool tool, string provider_id, string tool_id, string launcher_id
        ) {
            return provider_id == tool.provider_id && tool_id == tool.id &&
                launcher_id == tool.group.launcher.tool_target_id;
        }

        internal static bool owns_managed_installation (Tools.ProviderTool tool, string path) {
            Posix.Stat info;
            if (Posix.lstat (path, out info) != 0 || !Posix.S_ISDIR (info.st_mode))
                return false;

            var metadata = Utils.Metadata.load (path);
            return matches_managed_identity (tool, metadata.provider_id, metadata.tool_id, metadata.launcher_id);
        }

        private string usage_identifier_for (InstalledToolEntry entry) {
            if (!entry.has_compatibilitytool_vdf)
                return entry.directory_name;
            return entry.internal_title != "" ? entry.internal_title : entry.directory_name;
        }

        // A tool card represents all installed releases. Keep the preferred
        // installed entry for existing callers, but aggregate usage separately.
        private bool provider_has_used_release (Tools.ProviderTool tool) {
            foreach (var entry in entries) {
                string? identifier = null;
                if (entry.has_persisted_identity ()) {
                    if (persisted_identity_matches_tool (entry, tool))
                        identifier = usage_identifier_for (entry);
                } else if (legacy_metadata_matches_tool (entry, tool) &&
                           legacy_metadata_match_is_unambiguous (entry)) {
                    identifier = usage_identifier_for (entry);
                } else if (identifier_matches_tool (entry.directory_name, tool)) {
                    identifier = entry.directory_name;
                } else if (entry.has_compatibilitytool_vdf &&
                           (identifier_matches_tool (entry.internal_title, tool) ||
                            identifier_matches_tool (entry.display_title, tool))) {
                    identifier = usage_identifier_for (entry);
                }
                if (identifier != null &&
                    group.launcher.get_compatibility_tool_usage_count ((!) identifier) > 0)
                    return true;
            }
            return false;
        }

        private void set_tool_state (Tool tool, InstalledToolEntry entry, string usage_identifier) {
            tool.set_resolved_installation_state (
                entry,
                usage_identifier,
                (tool is Tools.ProviderTool)
                    ? provider_has_used_release ((Tools.ProviderTool) tool)
                    : group.launcher.get_compatibility_tool_usage_count (usage_identifier) > 0
            );
        }
    }
}
