namespace ProtonPlus.Models.Providers {
    internal class Vkd3dDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (
                    Category.VKD3D, SourceType.GITHUB, "vkd3d-proton", "VKD3D-Proton", "",
                    "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases", 1,
                    { new VariantDefinition ("standard", "default", "$release_name", true) },
                    { InstallLayout.replace ("default", "$release_name", "v", "vkd3d-proton-") }
                ),
                new ProviderDefinition (
                    Category.VKD3D, SourceType.GITHUB, "vkd3d-lutris", "VKD3D-Lutris", "",
                    "https://api.github.com/repos/lutris/vkd3d/releases", 2,
                    { new VariantDefinition ("standard", "default", "$release_name", true) },
                    {
                        InstallLayout.template ("default", "$release_name"),
                        InstallLayout.replace ("heroic", "$release_name", "v", "vkd3d-lutris-")
                    }
                )
            };
        }
    }
}
