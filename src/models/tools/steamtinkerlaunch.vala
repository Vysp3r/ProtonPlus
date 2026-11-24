namespace ProtonPlus.Models.Tools {
    public class SteamTinkerLaunch : Tool {
        public SteamTinkerLaunch (Models.Group group) {
            Object (group: group,
                    title: "Steam Tinker Launch",
                    repository_url: "https://github.com/sonic2kk/steamtinkerlaunch",
                    description: _ (
                        "Steam wrapper for configuring launch options, modding tools, and overlays for Proton and native Linux games."
            ));
            legacy = true;
            sort_priority = 12;
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
