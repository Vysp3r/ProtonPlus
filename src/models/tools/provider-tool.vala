namespace ProtonPlus.Models.Tools {
    public class ProviderTool : Tool {
        // ProviderTool owns tool identity, local variant configuration, and naming;
        // ReleaseCatalog owns all remote browsing state and source access.
        public ProtonPlus.Models.Providers.ProviderDefinition definition { get; construct; }
        public string endpoint {
            owned get { return definition.endpoint; }
        }
        public ProtonPlus.Models.Providers.ArchiveInstallRequirement archive_install_requirement { get; private set; }
        internal ProtonPlus.Models.Providers.InstallLayout install_layout { get; private set; }
        public string tag {
            owned get { return definition.tag; }
        }
        public Gee.LinkedList<Variant> variants { get; private set; default = new Gee.LinkedList<Variant> (); }

        public const int RELEASE_PAGE_SIZE = ReleaseCatalog.RELEASE_PAGE_SIZE;

        public ProviderTool.with_catalog (
            ProtonPlus.Models.Providers.ProviderDefinition definition,
            ProtonPlus.Providers.Sources.ReleaseSource release_source,
            Group group,
            ProtonPlus.Models.Providers.InstallLayout install_layout
        ) {
            Object (group: group, definition: definition);
            this.install_layout = install_layout;
            this.title = definition.title;
            this.description = Utils.safe_translate (definition.description);
            this.legacy = definition.legacy;
            this.sort_priority = definition.sort_priority;
            this.archive_install_requirement = definition.archive_install_requirement;
            this.set_identity (definition.provider_id, definition.source_id);
            this.initialize_release_catalog (new ReleaseCatalog (id, title, definition, release_source));

            foreach (var configured_variant in definition.get_variants ()) {
                this.variants.add (new Variant (
                    configured_variant.id,
                    configured_variant.name,
                    configured_variant.format,
                    configured_variant.is_default,
                    null,
                    configured_variant.compatibility
                ));
            }
        }

        public string get_directory_name (string release_name) {
            if (release_name.contains ("Latest"))
                return release_name;

            return install_layout.render (title, release_name);
        }

    }
}
