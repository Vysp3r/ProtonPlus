namespace ProtonPlus.Models.Providers {
    public class ProviderCatalog : Object {
        public static Tools.ProviderTool? create_tool (ProviderDefinition definition, Group group) {
            var install_layout = definition.get_install_layout (group.launcher.tool_target_family_id);
            if (install_layout == null)
                return null;

            var source = ProtonPlus.Providers.Sources.ReleaseSourceRegistry.create (definition.source_type);
            if (source == null)
                return null;

            return new Tools.ProviderTool.with_catalog (definition, source, group, install_layout);
        }
    }
}
