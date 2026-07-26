namespace ProtonPlus.Models.Tools {
    public abstract class Basic : Tool {
        // Basic tools receive their provider and source identities from the
        // runner definition that creates them.
        internal ProtonPlus.Models.Launchers.Runners.IRunner? source_runner { get; set; }
        internal string endpoint { get; set; }
        internal string directory_name_format { get; set; }
        public string tag { get; set; }

        public const int RELEASE_PAGE_SIZE = 25;

        // Normalizes one provider browse operation without changing this
        // tool's pagination state.  Implementations may advance through more
        // than one upstream response when their source requires it.
        public abstract async ReleasePage? fetch_release_page (int requested_page, out ReturnCode code);

        // Retains the stateful browse contract used by the UI.  Callers that
        // need discovery without changing browse state should use
        // fetch_release_page() or fetch_latest_eligible_release().
        public override async Gee.LinkedList<Release> load_more (out ReturnCode code) {
            var release_page = yield fetch_release_page (page, out code);
            if (code != ReturnCode.RELEASES_LOADED || release_page == null)
                return new Gee.LinkedList<Release> ();

            page = release_page.next_page;
            has_more = release_page.has_more;
            return release_page.releases;
        }

        // Finds the first eligible normalized release from the beginning of
        // the source without affecting the state used for browsing.
        public async Release? fetch_latest_eligible_release (out ReturnCode code) {
            var requested_page = 1;

            while (true) {
                var release_page = yield fetch_release_page (requested_page, out code);
                if (code != ReturnCode.RELEASES_LOADED || release_page == null)
                    return null;

                if (release_page.releases.size > 0)
                    return release_page.releases.get (0);

                if (!release_page.has_more)
                    return null;

                requested_page = release_page.next_page;
            }
        }

        public virtual string get_directory_name (string release_name) {
            if (release_name.contains ("Latest"))
                return release_name;

            var directory_name = new StringBuilder (directory_name_format);

            directory_name.replace ("$release_name", release_name);
            directory_name.replace ("$title", title);

            if (directory_name.len > 0 && directory_name.str[0] == '_') {
                directory_name.replace ("_", "", 1);
                directory_name.str = directory_name.str.ascii_down ();
            }

            if (directory_name.len > 0 && directory_name.str[0] == '!') {
                directory_name.replace ("!", "", 1);
                var split = directory_name.str.split (":");
                if (split.length >= 3)
                    directory_name.str = split[0].replace (split[1], split[2]);
            }

            if (directory_name.len > 0 && directory_name.str[0] == '&') {
                directory_name.replace ("&", "", 1);
                var split = directory_name.str.split (":");
                if (split.length >= 4)
                    directory_name.str = split[0].contains (split[1]) ? split[2] : split[3];
            }

            return directory_name.str;
        }

        private string render_variant_asset_name (Variant variant, string release_name, string tag_name) {
            var asset_name = new StringBuilder (variant.format);
            asset_name.replace ("$title", title);
            asset_name.replace ("$release_name", release_name);
            asset_name.replace ("$tag_name", tag_name);
            return asset_name.str;
        }

        private string get_archive_stem (string asset_name) {
            return Utils.ArchiveHelper.strip_archive_extension (asset_name);
        }

        private bool variant_matches_asset (string expected_asset_name, string asset_name) {
            if (asset_name == expected_asset_name)
                return true;

            return get_archive_stem (asset_name) == expected_asset_name;
        }

        public virtual Gee.LinkedList<Variant> create_release_variants (
            string release_name,
            string tag_name,
            Gee.LinkedList<ProtonPlus.Models.Assets.IAsset> assets,
            string? fallback_download_url = null
        ) {
            var release_variants = new Gee.LinkedList<Variant> ();

            foreach (var variant in this.variants) {
                string? variant_download_url = null;
                var expected_asset_name = render_variant_asset_name (variant, release_name, tag_name);

                foreach (var asset in assets) {
                    if (variant_matches_asset (expected_asset_name, asset.name)) {
                        variant_download_url = asset.download_url;
                        break;
                    }
                }

                if (variant_download_url == null && variant.is_default) {
                    variant_download_url = fallback_download_url;
                }

                release_variants.add (new Variant (
                    variant.name,
                    variant.format,
                    variant.is_default,
                    this,
                    variant_download_url,
                    variant.id
                ));
            }

            return release_variants;
        }

        public string? get_default_variant_download_url (Gee.LinkedList<Variant> release_variants, string? fallback_download_url = null) {
            foreach (var variant in release_variants) {
                if (variant.is_default && variant.download_url != null && variant.download_url != "") {
                    return variant.download_url;
                }
            }

            return fallback_download_url;
        }

        public virtual void update_variant_download_url (string release_name) {
            foreach (var variant in this.variants) {
                var url = new StringBuilder (variant.format);
                url.replace ("$title", title);
                url.replace ("$release_name", release_name);
                variant.download_url = url.str;
            }
        }

        private string get_variant_directory_suffix (Variant variant) {
            if (variant.is_default)
                return "";

            var sanitized_variant_name = variant.name.replace (" ", "_").replace ("/", "_");
            return "-%s".printf (sanitized_variant_name);
        }

        private bool identifier_matches_tool (string identifier) {
            if (identifier == "")
                return false;

            if (identifier == title || identifier == "%s Latest".printf (title))
                return true;

            if (releases == null || releases.size == 0)
                return false;

            foreach (var release in releases) {
                var directory_name = get_directory_name (release.title);
                if (identifier == directory_name)
                    return true;

                foreach (var variant in variants) {
                    if (identifier == "%s%s".printf (directory_name, get_variant_directory_suffix (variant)))
                        return true;
                }
            }

            return false;
        }

        private bool has_persisted_identity (InstalledToolEntry entry) {
            return entry.provider_id != "" || entry.tool_id != "" || entry.launcher_id != "" ||
                   entry.variant_id != "" || entry.release_id != "";
        }

        private bool persisted_identity_matches_tool (InstalledToolEntry entry) {
            if (entry.tool_id != "") {
                return entry.tool_id == id &&
                       (entry.provider_id == "" || entry.provider_id == provider_id) &&
                       (entry.launcher_id == "" || entry.launcher_id == group.launcher.instance_id);
            }

            return entry.provider_id != "" &&
                   entry.provider_id == provider_id &&
                   (entry.launcher_id == "" || entry.launcher_id == group.launcher.instance_id);
        }

        private bool legacy_metadata_matches_tool (InstalledToolEntry entry) {
            var endpoint_matches = entry.runner_endpoint != "" && entry.runner_endpoint == endpoint;
            var title_matches = entry.runner_title != "" && entry.runner_title == title;

            if (entry.runner_endpoint != "" && entry.runner_title != "")
                return endpoint_matches && title_matches;

            if (entry.runner_endpoint != "" || entry.runner_title != "")
                return endpoint_matches || title_matches;

            return legacy_tag_matches_tool (entry.tag);
        }

        private bool legacy_tag_matches_tool (string tag) {
            if (tag == "" || releases == null)
                return false;

            foreach (var release in releases) {
                if (tag == release.title || tag == release.source_tag)
                    return true;
            }

            return false;
        }

        private bool legacy_metadata_match_is_unambiguous (InstalledToolEntry entry) {
            var matches = 0;
            if (group.tools == null)
                return false;

            foreach (var candidate in group.tools) {
                var basic_candidate = candidate as Basic;
                if (basic_candidate != null && basic_candidate.legacy_metadata_matches_tool (entry))
                    matches++;
            }

            return matches == 1;
        }

        private void upgrade_legacy_metadata (InstalledToolEntry entry) {
            var metadata = Utils.Metadata.load (entry.path);
            metadata.provider_id = provider_id;
            metadata.tool_id = id;
            metadata.launcher_id = group.launcher.instance_id;
            metadata.save (entry.path);
        }

        private string get_usage_identifier (InstalledToolEntry entry) {
            if (!entry.has_compatibilitytool_vdf)
                return entry.directory_name;

            return entry.internal_title != "" ? entry.internal_title : entry.directory_name;
        }

        private string? get_installed_usage_identifier () {
            foreach (var entry in group.get_installed_tool_index ()) {
                if (has_persisted_identity (entry) && persisted_identity_matches_tool (entry))
                    return get_usage_identifier (entry);
            }

            foreach (var entry in group.get_installed_tool_index ()) {
                if (has_persisted_identity (entry))
                    continue;

                if (legacy_metadata_matches_tool (entry) && legacy_metadata_match_is_unambiguous (entry)) {
                    upgrade_legacy_metadata (entry);
                    return get_usage_identifier (entry);
                }
            }

            foreach (var entry in group.get_installed_tool_index ()) {
                if (has_persisted_identity (entry))
                    continue;

                if (identifier_matches_tool (entry.directory_name))
                    return entry.directory_name;

                if (!entry.has_compatibilitytool_vdf)
                    continue;

                if (identifier_matches_tool (entry.internal_title))
                    return entry.internal_title;

                if (identifier_matches_tool (entry.display_title))
                    return entry.internal_title != "" ? entry.internal_title : entry.display_title;
            }

            return null;
        }

        public override bool is_installed () {
            return get_installed_usage_identifier () != null;
        }

        public override bool is_used () {
            var usage_identifier = get_installed_usage_identifier ();
            if (usage_identifier == null)
                return false;

            return group.launcher.get_compatibility_tool_usage_count (usage_identifier) > 0;
        }

        public bool is_asset_exclude (string title, string[]? exclude_asset) {
            if (exclude_asset == null)
                return false;

            var excluded = false;

            foreach (var excluded_asset in exclude_asset) {
                if (title.contains (excluded_asset)) {
                    excluded = true;
                    break;
                }
            }

            return excluded;
        }
    }
}
