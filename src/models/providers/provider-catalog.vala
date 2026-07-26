namespace ProtonPlus.Models.Providers {
    public class ProviderCatalog : Object {
        public static Tools.ProviderTool? create_tool (ProviderDefinition definition, Group group) {
            var directory_name_format = get_directory_name_format (definition, group.launcher.family_id);
            if (directory_name_format == null)
                return null;

            var source = ProtonPlus.Providers.Sources.ReleaseSourceRegistry.create (definition.source_type);
            if (source == null)
                return null;

            return new Tools.ProviderTool.with_catalog (definition, source, group, directory_name_format);
        }

        private static string? get_directory_name_format (ProviderDefinition definition, string launcher_family_id) {
            foreach (var entry in definition.get_directory_name_formats ()) {
                if (entry.launcher_family_id == launcher_family_id)
                    return entry.format;
            }

            foreach (var entry in definition.get_directory_name_formats ()) {
                if (entry.launcher_family_id == "default")
                    return entry.format;
            }

            return null;
        }
    }
}
