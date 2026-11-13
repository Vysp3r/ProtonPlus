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
        private string[] alternate_format_values;

        public string[] alternate_formats {
            owned get { return copy_strings (alternate_format_values); }
        }

        public VariantDefinition (
            string id,
            string name,
            string format,
            bool is_default,
            VariantCompatibility? compatibility = null,
            string[]? alternate_formats = null
        ) {
            this.id = id;
            this.name = name;
            this.format = format;
            this.is_default = is_default;
            this.compatibility = compatibility != null ? compatibility.copy () : VariantCompatibility.unspecified ();
            this.alternate_format_values = copy_strings (alternate_formats);
        }

        public string[] get_asset_formats () {
            var formats = new string[alternate_format_values.length + 1];
            formats[0] = format;
            for (var index = 0; index < alternate_format_values.length; index++)
                formats[index + 1] = alternate_format_values[index];
            return formats;
        }

        internal VariantDefinition copy () {
            return new VariantDefinition (id, name, format, is_default, compatibility, alternate_formats);
        }

        private static string[] copy_strings (string[]? values) {
            if (values == null)
                return {};

            var copied = new string[values.length];
            for (var index = 0; index < values.length; index++)
                copied[index] = values[index];
            return copied;
        }
    }

    // Ordered packaging generations. The first set with a named asset match
    // describes the release; unmatched entries remain complete catalog data.
    public class ReleaseVariantSet : Object {
        private VariantDefinition[] variants;

        public ReleaseVariantSet (VariantDefinition[] variants) {
            this.variants = new VariantDefinition[variants.length];
            for (var index = 0; index < variants.length; index++)
                this.variants[index] = variants[index].copy ();
        }

        public VariantDefinition[] get_variants () {
            var copied = new VariantDefinition[variants.length];
            for (var index = 0; index < variants.length; index++)
                copied[index] = variants[index].copy ();
            return copied;
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

    // Named input for a definition. ProviderDefinition takes a defensive
    // snapshot, so later edits to this configuration cannot change live tools.
    public class ProviderConfig : Object {
        public Category category = Category.DXVK;
        public SourceType source_type = SourceType.GITHUB;
        public string provider_id = "";
        public string title = "";
        public string description = "";
        public string endpoint = "";
        public string repository_url = "";
        public int sort_priority = 0;
        public VariantDefinition[] variants = {};
        public ReleaseVariantSet[] release_variant_sets = {};
        public InstallLayout[] install_layouts = {};
        public string[] asset_filters = {};
        public string[] asset_exclusions = {};
        public string tag = "";
        public bool legacy = false;
        public string url_template = "";
        public ArchiveInstallRequirement archive_install_requirement = ArchiveInstallRequirement.STANDARD;
        public bool single_archive_releases = false;
        public string[] legacy_endpoints = {};
        public string[] legacy_titles = {};
    }

    // A definition deliberately contains no request or JSON behavior.  It is
    // safe to share as immutable configuration between catalog tool instances.
    public class ProviderDefinition : Object {
        public Category category { get; private set; }
        public SourceType source_type { get; private set; }
        public string provider_id { get; private set; }
        public string title { get; private set; }
        // Descriptions and user-visible tags are translated after composition.
        // Mark their definition literals with N_() so gettext can extract them.
        public string description { get; private set; }
        public string endpoint { get; private set; }
        public string repository_url { get; private set; }
        public int sort_priority { get; private set; }
        public bool legacy { get; private set; }
        public string tag { get; private set; }
        private VariantDefinition[] variants;
        private ReleaseVariantSet[] release_variant_sets;
        public bool has_release_variant_sets { get { return release_variant_sets.length > 0; } }
        private InstallLayout[] install_layouts;
        // These historically filter release titles, despite their older asset
        // names.  Keep the configuration and matching semantics unchanged.
        private string[] asset_filter_values;
        private string[] asset_exclusion_values;
        private string[] legacy_endpoint_values;
        private string[] legacy_title_values;
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

        public string[] legacy_titles {
            owned get { return copy_strings (legacy_title_values); }
        }

        public string source_id {
            owned get { return source_id_for (source_type); }
        }

        public ProviderDefinition (ProviderConfig config) {
            this.category = config.category;
            this.source_type = config.source_type;
            this.provider_id = config.provider_id;
            this.title = config.title;
            this.description = config.description;
            this.endpoint = config.endpoint;
            this.repository_url = config.repository_url;
            this.sort_priority = config.sort_priority;
            this.variants = copy_variants (config.variants);
            this.release_variant_sets = copy_variant_sets (config.release_variant_sets);
            this.install_layouts = copy_install_layouts (config.install_layouts);
            this.asset_filter_values = copy_strings (config.asset_filters);
            this.asset_exclusion_values = copy_strings (config.asset_exclusions);
            this.tag = config.tag;
            this.legacy = config.legacy;
            this.url_template = config.url_template;
            this.archive_install_requirement = config.archive_install_requirement;
            this.single_archive_releases = config.single_archive_releases;
            this.legacy_endpoint_values = copy_strings (config.legacy_endpoints);
            this.legacy_title_values = copy_strings (config.legacy_titles);
        }

        private static VariantDefinition[] copy_variants (VariantDefinition[] values) {
            var copied = new VariantDefinition[values.length];
            for (var index = 0; index < values.length; index++) {
                var value = values[index];
                copied[index] = new VariantDefinition (
                    value.id, value.name, value.format, value.is_default,
                    value.compatibility, value.alternate_formats
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
            // Tools retain the entire identity/compatibility universe, while
            // release composition selects one packaging generation below.
            var all = new ArrayList<VariantDefinition> ();
            var ids = new HashSet<string> ();
            foreach (var variant in variants) {
                all.add (variant.copy ());
                ids.add (variant.id);
            }
            foreach (var set in release_variant_sets)
                foreach (var variant in set.get_variants ())
                    if (ids.add (variant.id))
                        all.add (variant);
            return all.to_array ();
        }

        public VariantDefinition[] get_fallback_variants () {
            return copy_variants (variants);
        }

        public ReleaseVariantSet[] get_release_variant_sets () {
            return copy_variant_sets (release_variant_sets);
        }

        private static ReleaseVariantSet[] copy_variant_sets (ReleaseVariantSet[] sets) {
            var copied = new ReleaseVariantSet[sets.length];
            for (var index = 0; index < sets.length; index++)
                copied[index] = new ReleaseVariantSet (sets[index].get_variants ());
            return copied;
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

        public bool matches_title (string candidate) {
            if (candidate == "")
                return false;
            if (candidate == title)
                return true;
            foreach (var legacy_title in legacy_title_values) {
                if (candidate == legacy_title)
                    return true;
            }
            return false;
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
