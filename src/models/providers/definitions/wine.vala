namespace ProtonPlus.Models.Providers {
    internal class WineDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.WINE,
                    source_type = SourceType.GITHUB,
                    provider_id = "wine-proton",
                    title = "Wine-Proton (Kron4ek)",
                    description = N_ ("Wine build modified by Valve and other contributors."),
                    endpoint = "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    repository_url = "https://github.com/Kron4ek/Wine-Builds",
                    sort_priority = 1,
                    variants = {
                        new VariantDefinition ("x86-64", "default", "wine-$tag_name-amd64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("wow64", "wow64", "wine-$tag_name-amd64-wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("x86", "x86", "wine-$tag_name-x86", false, VariantCompatibility.for_architecture (CpuArchitecture.X86_32))
                    },
                    install_layouts = {
                        InstallLayout.template ("default", "wine-$release_name-amd64"),
                        InstallLayout.template ("bottles", "kron4ek-wine-$release_name-amd64")
                    },
                    asset_filters = { "proton" }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.WINE,
                    source_type = SourceType.GITHUB,
                    provider_id = "wine-staging",
                    title = "Wine-Staging (Kron4ek)",
                    description = N_ ("Wine build with the Staging patchset."),
                    endpoint = "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    repository_url = "https://github.com/Kron4ek/Wine-Builds",
                    sort_priority = 2,
                    variants = {
                        new VariantDefinition ("x86-64", "default", "wine-$tag_name-staging-amd64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("wow64", "wow64", "wine-$tag_name-staging-amd64-wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE))
                    },
                    install_layouts = {
                        InstallLayout.template ("default", "wine-$release_name-staging-amd64"),
                        InstallLayout.template ("bottles", "kron4ek-wine-$release_name-staging-amd64")
                    },
                    asset_exclusions = { "proton", ".0." }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.WINE,
                    source_type = SourceType.GITHUB,
                    provider_id = "wine-staging-tkg",
                    title = "Wine-Staging-Tkg (Kron4ek)",
                    description = N_ ("Wine build with the Staging patchset and many other useful patches."),
                    endpoint = "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    repository_url = "https://github.com/Kron4ek/Wine-Builds",
                    sort_priority = 3,
                    variants = {
                        new VariantDefinition ("x86-64", "default", "wine-$tag_name-staging-tkg-amd64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("wow64", "wow64", "wine-$tag_name-staging-tkg-amd64-wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE))
                    },
                    install_layouts = {
                        InstallLayout.template ("default", "wine-$release_name-staging-tkg-amd64"),
                        InstallLayout.template ("bottles", "kron4ek-wine-$release_name-staging-tkg-amd64")
                    },
                    asset_exclusions = { "proton", ".0." }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.WINE,
                    source_type = SourceType.GITHUB,
                    provider_id = "wine-vanilla",
                    title = "Wine-Vanilla (Kron4ek)",
                    description = N_ ("Wine build compiled from the official WineHQ sources."),
                    endpoint = "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    repository_url = "https://github.com/Kron4ek/Wine-Builds",
                    sort_priority = 4,
                    variants = {
                        new VariantDefinition ("x86-64", "default", "wine-$tag_name-amd64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("wow64", "wow64", "wine-$tag_name-amd64-wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE))
                    },
                    install_layouts = {
                        InstallLayout.template ("default", "wine-$release_name-amd64"),
                        InstallLayout.template ("bottles", "kron4ek-wine-$release_name-amd64")
                    },
                    asset_exclusions = { "proton", ".0." }
                })
            };
        }
    }
}
