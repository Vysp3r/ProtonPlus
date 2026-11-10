namespace ProtonPlus.Models.Providers {
    internal class ProtonDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB,
                    provider_id = "proton-ge",
                    title = "Proton-GE",
                    description = N_ ("Steam compatibility tool for running Windows games with improvements over Valve's default Proton."),
                    endpoint = "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases",
                    repository_url = "https://github.com/GloriousEggroll/proton-ge-custom",
                    sort_priority = 2,
                    variants = {
                        new VariantDefinition (
                            "x86", "x86_64", "$release_name-x86_64", true,
                            VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE),
                            { "$release_name" }
                        ),
                        new VariantDefinition ("aarch64", "aarch64", "$release_name-aarch64", false, VariantCompatibility.for_aarch64_level (Aarch64Level.V8_1))
                    },
                    install_layouts = {
                        InstallLayout.template ("default", "$release_name"),
                        InstallLayout.conditional ("steam", ".", "Proton-$release_name", "$release_name"),
                        InstallLayout.lowercase ("bottles", "$release_name"),
                        InstallLayout.template ("heroic", "Proton-$release_name")
                    }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB,
                    provider_id = "proton-cachyos",
                    title = "Proton-CachyOS",
                    description = N_ ("Steam compatibility tool from the CachyOS Linux distribution for running Windows games with improvements over Valve's default Proton."),
                    endpoint = "https://api.github.com/repos/CachyOS/proton-cachyos/releases",
                    repository_url = "https://github.com/CachyOS/proton-cachyos",
                    sort_priority = 1,
                    variants = {
                        new VariantDefinition ("x86-64", "x86_64", "proton-$tag_name-x86_64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("x86-64-v3", "x86_64_v3", "proton-$tag_name-x86_64_v3", false, VariantCompatibility.for_x86_64_level (X86_64Level.V3)),
                        new VariantDefinition ("arm64", "arm64", "proton-$tag_name-arm64", false, VariantCompatibility.for_aarch64_level (Aarch64Level.V8_1))
                    },
                    install_layouts = { InstallLayout.template ("default", "$release_name") },
                    tag = N_ ("Recommended")
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB,
                    provider_id = "dw-proton",
                    title = "DW-Proton",
                    description = N_ ("Dawn Winery's custom Proton build with additional game fixes and compatibility patches."),
                    endpoint = "https://api.github.com/repos/dawn-winery/dwproton-mirror/releases",
                    repository_url = "https://github.com/dawn-winery/dwproton-mirror",
                    sort_priority = 3,
                    variants = { new VariantDefinition ("x86-64", "x86_64", "$tag_name-x86_64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)) },
                    install_layouts = { InstallLayout.template ("default", "$release_name") },
                    single_archive_releases = true,
                    legacy_endpoints = { "https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases" }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB,
                    provider_id = "proton-ge-rtsp",
                    title = "Proton-RTSP",
                    description = N_ ("Custom Proton build based on Proton Experimental with additional patches for VRChat RTSP and media playback."),
                    endpoint = "https://api.github.com/repos/SpookySkeletons/proton-rtsp/releases",
                    repository_url = "https://github.com/SpookySkeletons/proton-rtsp",
                    sort_priority = 4,
                    variants = { new VariantDefinition ("standard", "default", "$tag_name.tar.gz", true) },
                    install_layouts = { InstallLayout.template ("default", "$release_name") },
                    legacy_endpoints = { "https://api.github.com/repos/SpookySkeletons/proton-ge-rtsp/releases" }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB_ACTIONS,
                    provider_id = "proton-tkg",
                    title = "Proton-Tkg",
                    description = N_ ("Custom Proton build for running Windows games, based on Wine-tkg."),
                    endpoint = "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/proton-valvexbe-sniper.yml/runs",
                    repository_url = "https://github.com/Frogging-Family/wine-tkg-git",
                    sort_priority = 5,
                    variants = { new VariantDefinition ("standard", "default", "$title-$release_name", true) },
                    install_layouts = { InstallLayout.template ("default", "$title-$release_name") },
                    url_template = "https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/{id}/proton-tkg-build.zip",
                    archive_install_requirement = ArchiveInstallRequirement.NESTED_ARCHIVE,
                    single_archive_releases = true
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB,
                    provider_id = "proton-em",
                    title = "Proton-EM",
                    description = N_ ("Development-oriented custom Proton build with FSR 4 support, Wine Wayland work, and other experimental patches."),
                    endpoint = "https://api.github.com/repos/BananaWorks07/Proton/releases",
                    repository_url = "https://github.com/BananaWorks07/Proton",
                    sort_priority = 6,
                    variants = { new VariantDefinition ("standard", "default", "proton-$release_name", true) },
                    install_layouts = { InstallLayout.template ("default", "$release_name") },
                    single_archive_releases = true,
                    legacy_endpoints = { "https://api.github.com/repos/Etaash-mathamsetty/Proton/releases" }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB,
                    provider_id = "proton-cachyos-wineland",
                    title = "Proton-Wineland",
                    legacy_titles = { "Proton-CachyOS Wineland" },
                    description = N_ ("Steam compatibility tool built with native Wayland support, smoother desktop integration, Steam overlay and other new features."),
                    endpoint = "https://api.github.com/repos/nanomatters/proton-cachyos/releases",
                    repository_url = "https://github.com/nanomatters/proton-cachyos",
                    sort_priority = 7,
                    variants = {
                        new VariantDefinition ("x86-64", "x86_64", "proton-$tag_name-x86_64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("x86-64-v3", "x86_64_v3", "proton-$tag_name-x86_64_v3", false, VariantCompatibility.for_x86_64_level (X86_64Level.V3)),
                        new VariantDefinition (
                            "x86-64-wow64", "x86_64_wow64", "proton-$tag_name-x86_64_wow64", false,
                            VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE),
                            { "proton-$tag_name-x86_64-wow64" }
                        )
                    },
                    install_layouts = { InstallLayout.template ("default", "$release_name") },
                    asset_exclusions = { "beta" }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.FORGEJO,
                    provider_id = "luxtorpeda",
                    title = "Luxtorpeda",
                    description = N_ ("Luxtorpeda provides Linux-native game engines for certain Windows-only games."),
                    endpoint = "https://codeberg.org/api/v1/repos/luxtorpeda/luxtorpeda/releases",
                    repository_url = "https://codeberg.org/luxtorpeda/luxtorpeda",
                    sort_priority = 8,
                    variants = { new VariantDefinition ("standard", "default", "luxtorpeda-$release_name", true) },
                    install_layouts = { InstallLayout.template ("default", "$title $release_name") },
                    single_archive_releases = true
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB,
                    provider_id = "boxtron",
                    title = "Boxtron",
                    description = N_ ("Steam compatibility tool for running DOS games using DOSBox for Linux."),
                    endpoint = "https://api.github.com/repos/dreamer/boxtron/releases",
                    repository_url = "https://github.com/dreamer/boxtron",
                    sort_priority = 9,
                    variants = { new VariantDefinition ("standard", "default", "boxtron.tar.xz", true) },
                    install_layouts = { InstallLayout.template ("default", "$title $release_name") },
                    legacy = true
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.PROTON,
                    source_type = SourceType.GITHUB,
                    provider_id = "roberta",
                    title = "Roberta",
                    description = N_ ("Steam compatibility tool for running adventure games using ScummVM for Linux."),
                    endpoint = "https://api.github.com/repos/dreamer/roberta/releases",
                    repository_url = "https://github.com/dreamer/roberta",
                    sort_priority = 10,
                    variants = { new VariantDefinition ("standard", "default", "roberta.tar.xz", true) },
                    install_layouts = { InstallLayout.template ("default", "$title $release_name") },
                    legacy = true
                })
            };
        }
    }
}
