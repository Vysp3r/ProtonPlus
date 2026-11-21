namespace ProtonPlus.Models.Providers {
    public class ProviderCatalog : Object {
        public static Tools.ProviderTool? create_tool (ProviderDefinition definition, Group group) {
            if (definition.archive_install_requirement == ArchiveInstallRequirement.STEAM_PROTON_AUTOGEN &&
                (!(group.launcher is Launchers.Steam) || group.launcher.installation_type != Launcher.InstallationTypes.SYSTEM))
                return null;

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
