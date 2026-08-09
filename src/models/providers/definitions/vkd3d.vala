namespace ProtonPlus.Models.Providers {
    internal class Vkd3dDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (
                    Category.VKD3D, SourceType.GITHUB, "vkd3d-proton", "VKD3D-Proton", "",
                    "https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases",
                    "https://github.com/HansKristian-Work/vkd3d-proton", 1,
                    { new VariantDefinition ("standard", "default", "vkd3d-proton-$release_version", true) },
                    { InstallLayout.replace ("default", "$release_name", "v", "vkd3d-proton-") },
                    null, null, "", false, "", ArchiveInstallRequirement.STANDARD, true
                ),
                new ProviderDefinition (
                    Category.VKD3D, SourceType.GITHUB, "vkd3d-lutris", "VKD3D-Lutris", "",
                    "https://api.github.com/repos/lutris/vkd3d/releases",
                    "https://github.com/lutris/vkd3d", 2,
                    { new VariantDefinition ("standard", "default", "vkd3d-$release_version", true) },
                    { InstallLayout.template ("default", "$release_name") },
                    null, null, "", false, "", ArchiveInstallRequirement.STANDARD, true
                )
            };
        }
    }
}
