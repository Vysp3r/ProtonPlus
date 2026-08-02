namespace ProtonPlus.Models.Tools {
    public class TinkerGame : Tool {
        public TinkerGame (Models.Group group) {
            Object (group: group,
                    title: "TinkerGame",
                    description: _ (
                        "Steam tool for easy, graphical configuration of your other compatibility tools for both Windows games and native Linux games."
            ));
            set_identity ("tinkergame", "github");

            // Remote commit lookup is performed explicitly by the installation
            // service for the target-bound job, never from a Release constructor.
            var release = new Release (
                title,
                description,
                "",
                new Models.Assets.Asset ("", ""),
                "",
                0,
                "tinkergame",
                "tinkergame",
                Release.Kind.TINKERGAME
            );
            initialize_release_catalog (new ReleaseCatalog.with_static_release (release));
        }

    }
}
