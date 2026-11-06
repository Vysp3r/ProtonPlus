namespace ProtonPlus.Models.Providers {
    internal class Vkd3dDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.VKD3D,
                    source_type = SourceType.GITHUB,
                    provider_id = "vkd3d-proton",
                    title = "VKD3D-Proton",
                    description = "",
                    endpoint = "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases",
                    repository_url = "https://github.com/HansKristian-Work/vkd3d-proton",
                    sort_priority = 1,
                    variants = { new VariantDefinition ("standard", "default", "vkd3d-proton-$release_version", true) },
                    install_layouts = { InstallLayout.replace ("default", "$release_name", "v", "vkd3d-proton-") },
                    single_archive_releases = true
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.VKD3D,
                    source_type = SourceType.GITHUB,
                    provider_id = "vkd3d-lutris",
                    title = "VKD3D-Lutris",
                    description = "",
                    endpoint = "https://api.github.com/repos/lutris/vkd3d/releases",
                    repository_url = "https://github.com/lutris/vkd3d",
                    sort_priority = 2,
                    variants = { new VariantDefinition ("standard", "default", "vkd3d-$release_version", true) },
                    install_layouts = { InstallLayout.template ("default", "$release_name") },
                    single_archive_releases = true
                })
            };
        }
    }
}
