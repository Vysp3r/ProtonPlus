namespace ProtonPlus.Models.Providers {
    internal class ProtonDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (
                    Category.PROTON, SourceType.GITHUB, "proton-ge", "Proton-GE",
                    "Steam compatibility tool for running Windows games with improvements over Valve's default Proton.",
                    "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 2,
                    {
                        new VariantDefinition ("x86", "x86", "$release_name", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("aarch64", "aarch64", "$release_name-aarch64", false, VariantCompatibility.for_architecture (CpuArchitecture.AARCH64))
                    },
                    {
                        InstallLayout.template ("default", "$release_name"),
                        InstallLayout.conditional ("steam", ".", "Proton-$release_name", "$release_name"),
                        InstallLayout.lowercase ("bottles", "$release_name"),
                        InstallLayout.template ("heroic", "Proton-$release_name")
                    }
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.GITHUB, "proton-cachyos", "Proton-CachyOS",
                    "Steam compatibility tool from the CachyOS Linux distribution for running Windows games with improvements over Valve's default Proton.",
                    "https://api.github.com/repos/CachyOS/proton-cachyos/releases", 1,
                    {
                        new VariantDefinition ("x86-64", "x86_64", "proton-$tag_name-x86_64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("x86-64-v3", "x86_64_v3", "proton-$tag_name-x86_64_v3", false, VariantCompatibility.for_x86_64_level (X86_64Level.V3)),
                        new VariantDefinition ("arm64", "arm64", "proton-$tag_name-arm64", false, VariantCompatibility.for_architecture (CpuArchitecture.AARCH64))
                    },
                    { InstallLayout.template ("default", "$release_name") }, null, null, "Recommended"
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.FORGEJO, "dw-proton", "DW-Proton",
                    "Dawn Winery's custom Proton fork with fixes for various games :xdd:",
                    "https://dawn.wine/api/v1/repos/dawn-winery/dwproton/releases", 3,
                    { new VariantDefinition ("x86-64", "x86_64", "$release_name-x86_64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)) },
                    { InstallLayout.template ("default", "$release_name") }
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.GITHUB, "proton-ge-rtsp", "Proton-GE RTSP",
                    "Steam compatibility tool based on Proton-GE with additional patches to improve RTSP codecs for VRChat.",
                    "https://api.github.com/repos/SpookySkeletons/proton-ge-rtsp/releases", 4,
                    { new VariantDefinition ("standard", "default", "$tag_name", true) },
                    { InstallLayout.template ("default", "$release_name") }
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.GITHUB_ACTIONS, "proton-tkg", "Proton-Tkg",
                    "Custom Proton build for running Windows games, based on Wine-tkg.",
                    "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/proton-valvexbe-sniper.yml/runs", 5,
                    { new VariantDefinition ("standard", "default", "$title-$release_name", true) },
                    { InstallLayout.template ("default", "$title-$release_name") }, null, null, "", false,
                    "https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/{id}/proton-tkg-build.zip",
                    ArchiveInstallRequirement.NESTED_ARCHIVE
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.GITHUB, "proton-em", "Proton-EM",
                    "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. " +
                    "By Etaash Mathamsetty, adding FSR4 support and Wine Wayland tweaks.",
                    "https://api.github.com/repos/Etaash-mathamsetty/Proton/releases", 6,
                    { new VariantDefinition ("standard", "default", "$release_name", true) },
                    { InstallLayout.template ("default", "$release_name") }
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.GITHUB, "proton-cachyos-wineland", "Proton-CachyOS Wineland",
                    "Steam compatibility tool based on CachyOS Proton with Wayland improvements, especially for Windows launcher applications.",
                    "https://api.github.com/repos/nanomatters/proton-cachyos/releases", 7,
                    {
                        new VariantDefinition ("x86-64", "x86_64", "proton-$tag_name-x86_64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("x86-64-v3", "x86_64_v3", "proton-$tag_name-x86_64_v3", false, VariantCompatibility.for_x86_64_level (X86_64Level.V3)),
                        new VariantDefinition ("x86-64-wow64", "x86_64_wow64", "proton-$tag_name-x86_64_wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE))
                    },
                    { InstallLayout.template ("default", "$release_name") }
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.FORGEJO, "luxtorpeda", "Luxtorpeda",
                    "Luxtorpeda provides Linux-native game engines for certain Windows-only games.",
                    "https://codeberg.org/api/v1/repos/luxtorpeda/luxtorpeda/releases", 8,
                    { new VariantDefinition ("standard", "default", "$title-$release_name", true) },
                    { InstallLayout.template ("default", "$title $release_name") }
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.GITHUB, "boxtron", "Boxtron",
                    "Steam compatibility tool for running DOS games using DOSBox for Linux.",
                    "https://api.github.com/repos/dreamer/boxtron/releases", 9,
                    { new VariantDefinition ("standard", "default", "$title", true) },
                    { InstallLayout.template ("default", "$title $release_name") }, null, null, "", true
                ),
                new ProviderDefinition (
                    Category.PROTON, SourceType.GITHUB, "roberta", "Roberta",
                    "Steam compatibility tool for running adventure games using ScummVM for Linux.",
                    "https://api.github.com/repos/dreamer/roberta/releases", 10,
                    { new VariantDefinition ("standard", "default", "$title", true) },
                    { InstallLayout.template ("default", "$title $release_name") }, null, null, "", true
                )
            };
        }
    }
}
