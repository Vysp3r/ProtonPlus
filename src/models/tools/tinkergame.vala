namespace ProtonPlus.Models.Tools {
    public class TinkerGame : Tool {
        public TinkerGame (Models.Group group, ProtonPlus.Providers.Sources.ReleaseSource? source = null) {
            Object (group: group, title: "TinkerGame",
                repository_url: "https://github.com/360900/tinkergame",
                description: _("Configure game tools and custom commands. Alpha software; review migrated settings before playing."));
            set_identity ("tinkergame", "github");
            var definition = new Providers.ProviderDefinition (new Providers.ProviderConfig () {
                category = Providers.Category.PROTON,
                source_type = Providers.SourceType.GITHUB,
                provider_id = "tinkergame",
                title = title,
                description = description,
                endpoint = "https://api.github.com/repos/360900/tinkergame/releases",
                repository_url = repository_url,
                sort_priority = 1000,
                variants = {},
                install_layouts = {}
            });
            initialize_release_catalog (new ReleaseCatalog (id, title, definition,
                source ?? new ProtonPlus.Providers.Sources.TinkerGameReleaseSource ()));
        }
    }
}
