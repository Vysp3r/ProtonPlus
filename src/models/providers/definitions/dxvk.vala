namespace ProtonPlus.Models.Providers {
    internal class DxvkDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (
                    Category.DXVK, SourceType.GITHUB, "dxvk-doitsujin", "DXVK (doitsujin)", "",
                    "https://api.github.com/repos/doitsujin/dxvk/releases", 1,
                    { new VariantDefinition ("standard", "default", "$release_name", true) },
                    { InstallLayout.replace ("default", "$release_name", "v", "dxvk-") }
                ),
                new ProviderDefinition (
                    Category.DXVK, SourceType.GITLAB, "dxvk-gplasync-ph42on", "DXVK GPL+Async (Ph42oN)",
                    "DXVK builds with gplasync patch by Ph42oN.",
                    "https://gitlab.com/api/v4/projects/Ph42oN%2Fdxvk-gplasync/releases", 2,
                    { new VariantDefinition ("standard", "default", "dxvk-gplasync-$release_name.tar.gz", true) },
                    { InstallLayout.template ("default", "dxvk-gplasync-$release_name") }
                ),
                new ProviderDefinition (
                    Category.DXVK, SourceType.GITHUB, "dxvk-sarek", "DXVK (Sarek)",
                    "DXVK builds that work with pre-Vulkan 1.3 versions.",
                    "https://api.github.com/repos/pythonlover02/DXVK-Sarek/releases", 3,
                    { new VariantDefinition ("standard", "default", "$release_name", true) },
                    { InstallLayout.template ("default", "sarek-$release_name") }
                )
            };
        }
    }
}
