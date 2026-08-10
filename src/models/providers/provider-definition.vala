namespace ProtonPlus.Models.Providers {
    using Gee;

    public enum Category {
        DXVK,
        VKD3D,
        PROTON,
        WINE,
    }

    public enum SourceType {
        GITHUB,
        GITHUB_ACTIONS,
        GITLAB,
        FORGEJO,
    }

    // A small, closed archive-shape capability. It belongs in provider
    // configuration because it describes the artifact a standard job will
    // receive, rather than the remote host that supplied it.
    public enum ArchiveInstallRequirement {
        STANDARD,
        NESTED_ARCHIVE,
    }

    // These values are configuration, not per-release state.  A tool creates
    // its own Models.Variant instances so no target can mutate another tool.
    public class VariantDefinition : Object {
        public string id { get; private set; }
        public string name { get; private set; }
        public string format { get; private set; }
        public bool is_default { get; private set; }
        public VariantCompatibility compatibility { get; private set; }

        public VariantDefinition (
            string id,
            string name,
            string format,
            bool is_default,
            VariantCompatibility? compatibility = null
        ) {
            this.id = id;
            this.name = name;
            this.format = format;
            this.is_default = is_default;
            this.compatibility = compatibility != null ? compatibility.copy () : VariantCompatibility.unspecified ();
        }
    }

    private enum InstallLayoutKind {
        TEMPLATE,
        LOWERCASE,
        REPLACE,
        CONDITIONAL,
    }

    // This is deliberately a small closed value object rather than a rule
    // hierarchy. Provider definitions are static configuration, so controlled
    // construction makes incomplete layout rules impossible in normal use.
    public class InstallLayout : Object {
        public string launcher_family_id { get; private set; }
        private InstallLayoutKind kind;
        private string layout_template;
        private string search;
        private string replacement;
        private string marker;
        private string true_template;
        private string false_template;

        private InstallLayout (
            string launcher_family_id,
            InstallLayoutKind kind,
            string template,
            string search,
            string replacement,
            string marker,
            string true_template,
            string false_template
        ) {
            switch (kind) {
            case InstallLayoutKind.TEMPLATE:
            case InstallLayoutKind.LOWERCASE:
                assert (template != "");
                break;
            case InstallLayoutKind.REPLACE:
                assert (template != "");
                assert (search != "");
                assert (replacement != "");
                break;
            case InstallLayoutKind.CONDITIONAL:
                assert (marker != "");
                assert (true_template != "");
                assert (false_template != "");
                break;
            default:
                assert_not_reached ();
            }

            this.launcher_family_id = launcher_family_id;
            this.kind = kind;
            this.layout_template = template;
            this.search = search;
            this.replacement = replacement;
            this.marker = marker;
            this.true_template = true_template;
            this.false_template = false_template;
        }

        public static InstallLayout template (string launcher_family_id, string template) {
            return new InstallLayout (
                launcher_family_id, InstallLayoutKind.TEMPLATE, template, "", "", "", "", ""
            );
        }

        public static InstallLayout lowercase (string launcher_family_id, string template) {
            return new InstallLayout (
                launcher_family_id, InstallLayoutKind.LOWERCASE, template, "", "", "", "", ""
            );
        }

        public static InstallLayout replace (
            string launcher_family_id,
            string template,
            string search,
            string replacement
        ) {
            return new InstallLayout (
                launcher_family_id, InstallLayoutKind.REPLACE, template, search, replacement, "", "", ""
            );
        }

        public static InstallLayout conditional (
            string launcher_family_id,
            string marker,
            string true_template,
            string false_template
        ) {
            return new InstallLayout (
                launcher_family_id, InstallLayoutKind.CONDITIONAL, "", "", "", marker, true_template, false_template
            );
        }

        internal InstallLayout copy () {
            return new InstallLayout (
                launcher_family_id, kind, layout_template, search, replacement, marker, true_template, false_template
            );
        }

        public string render (string title, string release_name) {
            switch (kind) {
            case InstallLayoutKind.TEMPLATE:
                return ProviderTemplate.render (layout_template, title, release_name);
            case InstallLayoutKind.LOWERCASE:
                return ProviderTemplate.render (layout_template, title, release_name).ascii_down ();
            case InstallLayoutKind.REPLACE:
                return ProviderTemplate.render (layout_template, title, release_name).replace (search, replacement);
            case InstallLayoutKind.CONDITIONAL:
                var selected_template = release_name.contains (marker) ? true_template : false_template;
                return ProviderTemplate.render (selected_template, title, release_name);
            default:
                assert_not_reached ();
            }
        }
    }

    // Provider strings intentionally only substitute the fixed placeholders
    // used by provider definitions. This is shared by layout and asset names,
    // not a general-purpose template engine.
    public class ProviderTemplate : Object {
        public static string render (
            string template,
            string title,
            string release_name,
            string? tag_name = null
        ) {
            var release_version = release_name.has_prefix ("v") ? release_name.substring (1) : release_name;
            var rendered = template.replace ("$title", title)
                                   .replace ("$release_version", release_version)
                                   .replace ("$release_name", release_name);
            if (tag_name == null)
                return rendered;

            return rendered.replace ("$tag_name", tag_name);
        }
    }

    // A definition deliberately contains no request or JSON behavior.  It is
    // safe to share as immutable configuration between catalog tool instances.
    public class ProviderDefinition : Object {
        public Category category { get; private set; }
        public SourceType source_type { get; private set; }
        public string provider_id { get; private set; }
        public string title { get; private set; }
        public string description { get; private set; }
        public string endpoint { get; private set; }
        public string repository_url { get; private set; }
        public int sort_priority { get; private set; }
        public bool legacy { get; private set; }
        public string tag { get; private set; }
        private VariantDefinition[] variants;
        private InstallLayout[] install_layouts;
        // These historically filter release titles, despite their older asset
        // names.  Keep the configuration and matching semantics unchanged.
        private string[] asset_filter_values;
        private string[] asset_exclusion_values;
        private string[] legacy_endpoint_values;
        public string url_template { get; private set; }
        public ArchiveInstallRequirement archive_install_requirement { get; private set; }
        public bool single_archive_releases { get; private set; }

        public string[] asset_filters {
            owned get { return copy_strings (asset_filter_values); }
        }

        public string[] asset_exclusions {
            owned get { return copy_strings (asset_exclusion_values); }
        }

        public string[] legacy_endpoints {
            owned get { return copy_strings (legacy_endpoint_values); }
        }

        public string source_id {
            owned get { return source_id_for (source_type); }
        }

        public ProviderDefinition (
            Category category,
            SourceType source_type,
            string provider_id,
            string title,
            string description,
            string endpoint,
            string repository_url,
            int sort_priority,
            VariantDefinition[] variants,
            InstallLayout[] install_layouts,
            string[]? asset_filters = null,
            string[]? asset_exclusions = null,
            string tag = "",
            bool legacy = false,
            string url_template = "",
            ArchiveInstallRequirement archive_install_requirement = ArchiveInstallRequirement.STANDARD,
            bool single_archive_releases = false,
            string[]? legacy_endpoints = null
        ) {
            this.category = category;
            this.source_type = source_type;
            this.provider_id = provider_id;
            this.title = title;
            this.description = description;
            this.endpoint = endpoint;
            this.repository_url = repository_url;
            this.sort_priority = sort_priority;
            this.variants = copy_variants (variants);
            this.install_layouts = copy_install_layouts (install_layouts);
            this.asset_filter_values = copy_strings (asset_filters);
            this.asset_exclusion_values = copy_strings (asset_exclusions);
            this.legacy_endpoint_values = copy_strings (legacy_endpoints);
            this.tag = tag;
            this.legacy = legacy;
            this.url_template = url_template;
            this.archive_install_requirement = archive_install_requirement;
            this.single_archive_releases = single_archive_releases;
        }

        private static VariantDefinition[] copy_variants (VariantDefinition[] values) {
            var copied = new VariantDefinition[values.length];
            for (var index = 0; index < values.length; index++) {
                var value = values[index];
                copied[index] = new VariantDefinition (
                    value.id, value.name, value.format, value.is_default, value.compatibility
                );
            }
            return copied;
        }

        private static InstallLayout[] copy_install_layouts (InstallLayout[] values) {
            var copied = new InstallLayout[values.length];
            for (var index = 0; index < values.length; index++) {
                var value = values[index];
                copied[index] = value.copy ();
            }
            return copied;
        }

        private static string[] copy_strings (string[]? values) {
            if (values == null)
                return {};

            var copied = new string[values.length];
            for (var index = 0; index < values.length; index++)
                copied[index] = values[index];
            return copied;
        }

        public VariantDefinition[] get_variants () {
            return copy_variants (variants);
        }

        public InstallLayout[] get_install_layouts () {
            return copy_install_layouts (install_layouts);
        }

        public InstallLayout? get_install_layout (string launcher_family_id) {
            foreach (var layout in install_layouts) {
                if (layout.launcher_family_id == launcher_family_id)
                    return layout.copy ();
            }

            foreach (var layout in install_layouts) {
                if (layout.launcher_family_id == "default")
                    return layout.copy ();
            }

            return null;
        }

        public bool matches_endpoint (string candidate) {
            if (candidate == "")
                return false;
            if (candidate == endpoint)
                return true;

            foreach (var legacy_endpoint in legacy_endpoint_values) {
                if (candidate == legacy_endpoint)
                    return true;
            }
            return false;
        }

        public static string source_id_for (SourceType source_type) {
            switch (source_type) {
            case SourceType.GITHUB:
                return "github";
            case SourceType.GITHUB_ACTIONS:
                return "github-actions";
            case SourceType.GITLAB:
                return "gitlab";
            case SourceType.FORGEJO:
                return "forgejo";
            default:
                return "";
            }
        }
    }

}
