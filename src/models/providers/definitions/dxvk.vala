namespace ProtonPlus.Models.Providers {
    internal class DxvkDefinitions : Object {
        internal static ProviderDefinition[] create () {
            return {
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.DXVK,
                    source_type = SourceType.GITHUB,
                    provider_id = "dxvk-doitsujin",
                    title = "DXVK (doitsujin)",
                    description = "",
                    endpoint = "https://api.github.com/repos/doitsujin/dxvk/releases",
                    repository_url = "https://github.com/doitsujin/dxvk",
                    sort_priority = 1,
                    variants = { new VariantDefinition ("standard", "default", "dxvk-$release_version", true) },
                    install_layouts = { InstallLayout.replace ("default", "$release_name", "v", "dxvk-") }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.DXVK,
                    source_type = SourceType.GITLAB,
                    provider_id = "dxvk-gplasync-ph42on",
                    title = "DXVK GPL+Async (Ph42oN)",
                    description = N_ ("DXVK builds with gplasync patch by Ph42oN."),
                    endpoint = "https://gitlab.com/api/v4/projects/Ph42oN%2Fdxvk-gplasync/releases",
                    repository_url = "https://gitlab.com/Ph42oN/dxvk-gplasync",
                    sort_priority = 2,
                    variants = { new VariantDefinition ("standard", "default", "dxvk-gplasync-$release_name.tar.gz", true) },
                    install_layouts = { InstallLayout.template ("default", "dxvk-gplasync-$release_name") }
                }),
                new ProviderDefinition (new ProviderConfig () {
                    category = Category.DXVK,
                    source_type = SourceType.GITHUB,
                    provider_id = "dxvk-sarek",
                    title = "DXVK (Sarek)",
                    description = N_ ("DXVK build targeting Vulkan 1.1/1.2 hardware, with backported fixes and support for older GPUs."),
                    endpoint = "https://api.github.com/repos/pythonlover02/DXVK-Sarek/releases",
                    repository_url = "https://github.com/pythonlover02/DXVK-Sarek",
                    sort_priority = 3,
                    variants = {
                        new VariantDefinition (
                            "standard", "default", "dxvk-sarek-$release_version", true, null,
                            {
                                "dxvk-sarek-dyasync-$release_name",
                                "dxvk-sarek-async-$release_name",
                                "dxvk-sarek-$release_name"
                            }
                        )
                    },
                    release_variant_sets = {
                        new ReleaseVariantSet ({
                            new VariantDefinition ("standard", N_ ("Default"), "dxvk-sarek-$release_version", true)
                        }),
                        new ReleaseVariantSet ({
                            new VariantDefinition ("standard", "dyasync", "dxvk-sarek-dyasync-$release_name", true)
                        }),
                        new ReleaseVariantSet ({
                            // The historical default slot contains Async.
                            // Preserve its ID and unsuffixed directory name.
                            new VariantDefinition ("standard", N_ ("Async"), "dxvk-sarek-async-$release_name", true),
                            new VariantDefinition ("non-async", N_ ("Standard"), "dxvk-sarek-$release_name", false)
                        })
                    },
                    install_layouts = { InstallLayout.template ("default", "sarek-$release_name") }
                })
            };
        }
    }
}
