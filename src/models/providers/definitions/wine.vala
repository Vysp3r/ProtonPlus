namespace ProtonPlus.Models.Providers {
    internal class WineDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (
                    Category.WINE, SourceType.GITHUB, "wine-proton", "Wine-Proton (Kron4ek)",
                    "Wine build modified by Valve and other contributors.",
                    "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    "https://github.com/Kron4ek/Wine-Builds", 1,
                    {
                        new VariantDefinition ("x86-64", "default", "wine-$tag_name-amd64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("wow64", "wow64", "wine-$tag_name-amd64-wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("x86", "x86", "wine-$tag_name-x86", false, VariantCompatibility.for_architecture (CpuArchitecture.X86_32))
                    },
                    {
                        InstallLayout.template ("default", "wine-$release_name-amd64"),
                        InstallLayout.template ("bottles", "kron4ek-wine-$release_name-amd64")
                    },
                    { "proton" }
                ),
                new ProviderDefinition (
                    Category.WINE, SourceType.GITHUB, "wine-staging", "Wine-Staging (Kron4ek)",
                    "Wine build with the Staging patchset.",
                    "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    "https://github.com/Kron4ek/Wine-Builds", 2,
                    {
                        new VariantDefinition ("x86-64", "default", "wine-$tag_name-staging-amd64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("wow64", "wow64", "wine-$tag_name-staging-amd64-wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE))
                    },
                    {
                        InstallLayout.template ("default", "wine-$release_name-staging-amd64"),
                        InstallLayout.template ("bottles", "kron4ek-wine-$release_name-staging-amd64")
                    }, null, { "proton", ".0." }
                ),
                new ProviderDefinition (
                    Category.WINE, SourceType.GITHUB, "wine-staging-tkg", "Wine-Staging-Tkg (Kron4ek)",
                    "Wine build with the Staging patchset and many other useful patches.",
                    "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    "https://github.com/Kron4ek/Wine-Builds", 3,
                    {
                        new VariantDefinition ("x86-64", "default", "wine-$tag_name-staging-tkg-amd64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("wow64", "wow64", "wine-$tag_name-staging-tkg-amd64-wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE))
                    },
                    {
                        InstallLayout.template ("default", "wine-$release_name-staging-tkg-amd64"),
                        InstallLayout.template ("bottles", "kron4ek-wine-$release_name-staging-tkg-amd64")
                    }, null, { "proton", ".0." }
                ),
                new ProviderDefinition (
                    Category.WINE, SourceType.GITHUB, "wine-vanilla", "Wine-Vanilla (Kron4ek)",
                    "Wine build compiled from the official WineHQ sources.",
                    "https://api.github.com/repos/Kron4ek/Wine-Builds/releases",
                    "https://github.com/Kron4ek/Wine-Builds", 4,
                    {
                        new VariantDefinition ("x86-64", "default", "wine-$tag_name-amd64", true, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
                        new VariantDefinition ("wow64", "wow64", "wine-$tag_name-amd64-wow64", false, VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE))
                    },
                    {
                        InstallLayout.template ("default", "wine-$release_name-amd64"),
                        InstallLayout.template ("bottles", "kron4ek-wine-$release_name-amd64")
                    }, null, { "proton", ".0." }
                )
            };
        }
    }
}
