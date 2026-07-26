namespace ProtonPlus.Models.Tools {
    public class SteamTinkerLaunch : Tool {
        public SteamTinkerLaunch (Models.Group group) {
            Object (group: group,
                    title: "Steam Tinker Launch",
                    description: _ (
                        "Steam tool for easy, graphical configuration of your other compatibility tools for both Windows games and native Linux games."
                    ));
            set_identity ("steam-tinker-launch", "github");
        }

        public override async Gee.LinkedList<Release> load_more (out ReturnCode code) {
            code = ReturnCode.RELEASES_LOADED;

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

            var _releases = new Gee.LinkedList<Release> ();
            _releases.add (release);

            return _releases;
        }

        public override bool is_installed () {
            foreach (var entry in group.get_installed_tool_index ()) {
                if (entry.directory_name == "SteamTinkerLaunch")
                    return true;
            }
            return false;
        }

        public override bool is_used () {
            return group.launcher.get_compatibility_tool_usage_count ("Proton-stl") > 0;
        }
    }
}
