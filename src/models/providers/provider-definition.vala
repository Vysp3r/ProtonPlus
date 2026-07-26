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

    // These values are configuration, not per-release state.  A tool creates
    // its own Models.Variant instances so no target can mutate another tool.
    public class VariantDefinition : Object {
        public string id { get; private set; }
        public string name { get; private set; }
        public string format { get; private set; }
        public bool is_default { get; private set; }

        public VariantDefinition (string id, string name, string format, bool is_default) {
            this.id = id;
            this.name = name;
            this.format = format;
            this.is_default = is_default;
        }
    }

    public class DirectoryNameFormat : Object {
        public string launcher_family_id { get; private set; }
        public string format { get; private set; }

        public DirectoryNameFormat (string launcher_family_id, string format) {
            this.launcher_family_id = launcher_family_id;
            this.format = format;
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
        public int sort_priority { get; private set; }
        public bool legacy { get; private set; }
        public string tag { get; private set; }
        private VariantDefinition[] variants;
        private DirectoryNameFormat[] directory_name_formats;
        // These historically filter release titles, despite their older asset
        // names.  Keep the configuration and matching semantics unchanged.
        public string[] asset_filters { get; private set; }
        public string[] asset_exclusions { get; private set; }
        public string url_template { get; private set; }

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
            int sort_priority,
            VariantDefinition[] variants,
            DirectoryNameFormat[] directory_name_formats,
            string[]? asset_filters = null,
            string[]? asset_exclusions = null,
            string tag = "",
            bool legacy = false,
            string url_template = ""
        ) {
            this.category = category;
            this.source_type = source_type;
            this.provider_id = provider_id;
            this.title = title;
            this.description = description;
            this.endpoint = endpoint;
            this.sort_priority = sort_priority;
            this.variants = copy_variants (variants);
            this.directory_name_formats = copy_directory_name_formats (directory_name_formats);
            this.asset_filters = copy_strings (asset_filters);
            this.asset_exclusions = copy_strings (asset_exclusions);
            this.tag = tag;
            this.legacy = legacy;
            this.url_template = url_template;
        }

        private static VariantDefinition[] copy_variants (VariantDefinition[] values) {
            var copied = new VariantDefinition[values.length];
            for (var index = 0; index < values.length; index++) {
                var value = values[index];
                copied[index] = new VariantDefinition (value.id, value.name, value.format, value.is_default);
            }
            return copied;
        }

        private static DirectoryNameFormat[] copy_directory_name_formats (DirectoryNameFormat[] values) {
            var copied = new DirectoryNameFormat[values.length];
            for (var index = 0; index < values.length; index++) {
                var value = values[index];
                copied[index] = new DirectoryNameFormat (value.launcher_family_id, value.format);
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

        public DirectoryNameFormat[] get_directory_name_formats () {
            return copy_directory_name_formats (directory_name_formats);
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

    public class ProviderDefinitions : Object {
        private HashMap<Category, ArrayList<ProviderDefinition>> definitions =
            new HashMap<Category, ArrayList<ProviderDefinition>> ();

        public ProviderDefinitions () {
            definitions.set (Category.DXVK, new ArrayList<ProviderDefinition> ());
            definitions.set (Category.VKD3D, new ArrayList<ProviderDefinition> ());
            definitions.set (Category.PROTON, new ArrayList<ProviderDefinition> ());
            definitions.set (Category.WINE, new ArrayList<ProviderDefinition> ());

            add (new ProviderDefinition (
                Category.DXVK, SourceType.GITHUB, "dxvk-doitsujin", "DXVK (doitsujin)", "",
                "https://api.github.com/repos/doitsujin/dxvk/releases", 1,
                { new VariantDefinition ("standard", "default", "$release_name", true) },
                { new DirectoryNameFormat ("default", "!$release_name:v:dxvk-") }
            ));
            add (new ProviderDefinition (
                Category.DXVK, SourceType.GITLAB, "dxvk-gplasync-ph42on", "DXVK GPL+Async (Ph42oN)",
                "DXVK builds with gplasync patch by Ph42oN.",
                "https://gitlab.com/api/v4/projects/Ph42oN%2Fdxvk-gplasync/releases", 2,
                { new VariantDefinition ("standard", "default", "dxvk-gplasync-$release_name.tar.gz", true) },
                { new DirectoryNameFormat ("default", "dxvk-gplasync-$release_name") }
            ));
            add (new ProviderDefinition (
                Category.DXVK, SourceType.GITHUB, "dxvk-sarek", "DXVK (Sarek)",
                "DXVK builds that work with pre-Vulkan 1.3 versions.",
                "https://api.github.com/repos/pythonlover02/DXVK-Sarek/releases", 3,
                { new VariantDefinition ("standard", "default", "$release_name", true) },
                { new DirectoryNameFormat ("default", "sarek-$release_name") }
            ));

            add (new ProviderDefinition (
                Category.VKD3D, SourceType.GITHUB, "vkd3d-proton", "VKD3D-Proton", "",
                "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases", 1,
                { new VariantDefinition ("standard", "default", "$release_name", true) },
                { new DirectoryNameFormat ("default", "!$release_name:v:vkd3d-proton-") }
            ));
            add (new ProviderDefinition (
                Category.VKD3D, SourceType.GITHUB, "vkd3d-lutris", "VKD3D-Lutris", "",
                "https://api.github.com/repos/lutris/vkd3d/releases", 2,
                { new VariantDefinition ("standard", "default", "$release_name", true) },
                {
                    new DirectoryNameFormat ("default", "$release_name"),
                    new DirectoryNameFormat ("heroic", "!$release_name:v:vkd3d-lutris-")
                }
            ));

            add (new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "proton-ge", "Proton-GE",
                "Steam compatibility tool for running Windows games with improvements over Valve's default Proton.",
                "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 2,
                {
                    new VariantDefinition ("x86", "x86", "$release_name", true),
                    new VariantDefinition ("aarch64", "aarch64", "$release_name-aarch64", false)
                },
                {
                    new DirectoryNameFormat ("default", "$release_name"),
                    new DirectoryNameFormat ("steam", "&$release_name:.:Proton-$release_name:$release_name"),
                    new DirectoryNameFormat ("bottles", "_$release_name"),
                    new DirectoryNameFormat ("heroic", "Proton-$release_name")
                }
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "proton-cachyos", "Proton-CachyOS",
                "Steam compatibility tool from the CachyOS Linux distribution for running Windows games with improvements over Valve's default Proton.",
                "https://api.github.com/repos/CachyOS/proton-cachyos/releases", 1,
                {
                    new VariantDefinition ("x86-64", "x86_64", "proton-$tag_name-x86_64", true),
                    new VariantDefinition ("x86-64-v3", "x86_64_v3", "proton-$tag_name-x86_64_v3", false),
                    new VariantDefinition ("arm64", "arm64", "proton-$tag_name-arm64", false)
                },
                { new DirectoryNameFormat ("default", "$release_name") }, null, null, "Recommended"
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.FORGEJO, "dw-proton", "DW-Proton",
                "Dawn Winery's custom Proton fork with fixes for various games :xdd:",
                "https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases", 3,
                { new VariantDefinition ("x86-64", "x86_64", "$release_name-x86_64", true) },
                { new DirectoryNameFormat ("default", "$release_name") }
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "proton-ge-rtsp", "Proton-GE RTSP",
                "Steam compatibility tool based on Proton-GE with additional patches to improve RTSP codecs for VRChat.",
                "https://api.github.com/repos/SpookySkeletons/proton-ge-rtsp/releases", 4,
                { new VariantDefinition ("standard", "default", "$tag_name", true) },
                { new DirectoryNameFormat ("default", "$release_name") }
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB_ACTIONS, "proton-tkg", "Proton-Tkg",
                "Custom Proton build for running Windows games, based on Wine-tkg.",
                "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/proton-valvexbe-sniper.yml/runs", 5,
                { new VariantDefinition ("standard", "default", "$title-$release_name", true) },
                { new DirectoryNameFormat ("default", "$title-$release_name") }, null, null, "", false,
                "https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/{id}/proton-tkg-build.zip"
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "proton-em", "Proton-EM",
                "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. " +
                "By Etaash Mathamsetty, adding FSR4 support and Wine Wayland tweaks.",
                "https://api.github.com/repos/Etaash-mathamsetty/Proton/releases", 6,
                { new VariantDefinition ("standard", "default", "$release_name", true) },
                { new DirectoryNameFormat ("default", "$release_name") }
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "proton-cachyos-wineland", "Proton-CachyOS Wineland",
                "Steam compatibility tool based on CachyOS Proton with Wayland improvements, especially for Windows launcher applications.",
                "https://api.github.com/repos/nanomatters/proton-cachyos/releases", 7,
                {
                    new VariantDefinition ("x86-64", "x86_64", "proton-$tag_name-x86_64", true),
                    new VariantDefinition ("x86-64-v3", "x86_64_v3", "proton-$tag_name-x86_64_v3", false),
                    new VariantDefinition ("x86-64-wow64", "x86_64_wow64", "proton-$tag_name-x86_64_wow64", false)
                },
                { new DirectoryNameFormat ("default", "$release_name") }
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.FORGEJO, "luxtorpeda", "Luxtorpeda",
                "Luxtorpeda provides Linux-native game engines for certain Windows-only games.",
                "https://codeberg.org/api/v1/repos/luxtorpeda/luxtorpeda/releases", 8,
                { new VariantDefinition ("standard", "default", "$title-$release_name", true) },
                { new DirectoryNameFormat ("default", "$title $release_name") }
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "boxtron", "Boxtron",
                "Steam compatibility tool for running DOS games using DOSBox for Linux.",
                "https://api.github.com/repos/dreamer/boxtron/releases", 9,
                { new VariantDefinition ("standard", "default", "$title", true) },
                { new DirectoryNameFormat ("default", "$title $release_name") }, null, null, "", true
            ));
            add (new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "roberta", "Roberta",
                "Steam compatibility tool for running adventure games using ScummVM for Linux.",
                "https://api.github.com/repos/dreamer/roberta/releases", 10,
                { new VariantDefinition ("standard", "default", "$title", true) },
                { new DirectoryNameFormat ("default", "$title $release_name") }, null, null, "", true
            ));

            add (new ProviderDefinition (
                Category.WINE, SourceType.GITHUB, "wine-proton", "Wine-Proton (Kron4ek)",
                "Wine build modified by Valve and other contributors.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 1,
                {
                    new VariantDefinition ("x86-64", "default", "wine-$tag_name-amd64", true),
                    new VariantDefinition ("wow64", "wow64", "wine-$tag_name-amd64-wow64", false),
                    new VariantDefinition ("x86", "x86", "wine-$tag_name-x86", false)
                },
                {
                    new DirectoryNameFormat ("default", "wine-$release_name-amd64"),
                    new DirectoryNameFormat ("bottles", "kron4ek-wine-$release_name-amd64")
                },
                { "proton" }
            ));
            add (new ProviderDefinition (
                Category.WINE, SourceType.GITHUB, "wine-staging", "Wine-Staging (Kron4ek)",
                "Wine build with the Staging patchset.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 2,
                {
                    new VariantDefinition ("x86-64", "default", "wine-$tag_name-staging-amd64", true),
                    new VariantDefinition ("wow64", "wow64", "wine-$tag_name-staging-amd64-wow64", false)
                },
                {
                    new DirectoryNameFormat ("default", "wine-$release_name-staging-amd64"),
                    new DirectoryNameFormat ("bottles", "kron4ek-wine-$release_name-staging-amd64")
                }, null, { "proton", ".0." }
            ));
            add (new ProviderDefinition (
                Category.WINE, SourceType.GITHUB, "wine-staging-tkg", "Wine-Staging-Tkg (Kron4ek)",
                "Wine build with the Staging patchset and many other useful patches.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 3,
                {
                    new VariantDefinition ("x86-64", "default", "wine-$tag_name-staging-tkg-amd64", true),
                    new VariantDefinition ("wow64", "wow64", "wine-$tag_name-staging-tkg-amd64-wow64", false)
                },
                {
                    new DirectoryNameFormat ("default", "wine-$release_name-staging-tkg-amd64"),
                    new DirectoryNameFormat ("bottles", "kron4ek-wine-$release_name-staging-tkg-amd64")
                }, null, { "proton", ".0." }
            ));
            add (new ProviderDefinition (
                Category.WINE, SourceType.GITHUB, "wine-vanilla", "Wine-Vanilla (Kron4ek)",
                "Wine build compiled from the official WineHQ sources.",
                "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 4,
                {
                    new VariantDefinition ("x86-64", "default", "wine-$tag_name-amd64", true),
                    new VariantDefinition ("wow64", "wow64", "wine-$tag_name-amd64-wow64", false)
                },
                {
                    new DirectoryNameFormat ("default", "wine-$release_name-amd64"),
                    new DirectoryNameFormat ("bottles", "kron4ek-wine-$release_name-amd64")
                }, null, { "proton", ".0." }
            ));
        }

        private void add (ProviderDefinition definition) {
            var entries = definitions.get (definition.category);
            assert (entries != null);
            entries.add (definition);
        }

        public new ArrayList<ProviderDefinition> get (Category category) {
            var values = definitions.get (category);
            var copied = new ArrayList<ProviderDefinition> ();
            if (values != null)
                copied.add_all (values);
            return copied;
        }

        public ArrayList<ProviderDefinition> get_all () {
            var copied = new ArrayList<ProviderDefinition> ();
            foreach (var category in new Category[] { Category.DXVK, Category.VKD3D, Category.PROTON, Category.WINE })
                copied.add_all (get (category));
            return copied;
        }
    }
}
