namespace ProtonPlus.Models.Tools {
    public class SteamTinkerLaunch : Tool {
        public SteamTinkerLaunch (Models.Group group) {
            Object (group: group,
                    title: "Steam Tinker Launch",
                    description: _ (
                        "Steam tool for easy, graphical configuration of your other compatibility tools for both Windows games and native Linux games."
            ));
            set_identity ("steam-tinker-launch", "github");

            // Remote commit lookup is performed explicitly by the installation
            // service for the target-bound job, never from a Release constructor.
            var release = new Release (
                title,
                description,
                "",
                new Models.Assets.Asset ("", ""),
                "",
                0,
                "steam-tinker-launch",
                "steam-tinker-launch",
                Release.Kind.STEAM_TINKER_LAUNCH
            );
            initialize_release_catalog (new ReleaseCatalog.with_static_release (release));
        }

    }
}
