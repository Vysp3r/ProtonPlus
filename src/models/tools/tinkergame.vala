namespace ProtonPlus.Models.Tools {
    public class TinkerGame : Tool {
        public TinkerGame (Models.Group group, ProtonPlus.Providers.Sources.ReleaseSource? source = null) {
            Object (group: group, title: "TinkerGame",
                repository_url: "https://github.com/360900/tinkergame",
                description: _("Configure game tools and custom commands. Alpha software; review migrated settings before playing."));
            set_identity ("tinkergame", "github");
            var definition = new Providers.ProviderDefinition (
                Providers.Category.PROTON, Providers.SourceType.GITHUB,
                "tinkergame", title, description,
                "https://api.github.com/repos/360900/tinkergame/releases",
                repository_url, 1000, {}, {}
            );
            initialize_release_catalog (new ReleaseCatalog (id, title, definition,
                source ?? new ProtonPlus.Providers.Sources.TinkerGameReleaseSource ()));
        }
    }
}
