namespace ProtonPlus.Models.Tools {
    public class SteamTinkerLaunch : Tool {
        public SteamTinkerLaunch (Models.Group group) {
            Object (group: group,
                    title: "Steam Tinker Launch",
                    description: _ ("Steam tool for easy, graphical configuration of your other compatibility tools for both Windows games and native Linux games."));
        }

        public override async Gee.LinkedList<Release> load_more (out ReturnCode code) {
            code = ReturnCode.RELEASES_LOADED;

            var release = new Releases.SteamTinkerLaunch (this);

            var _releases = new Gee.LinkedList<Release> ();
            _releases.add (release);

            return _releases;
        }

        public override bool is_installed () {
            var directories = group.get_tool_directories ();
            foreach (var directory in directories) {
                if (directory == "SteamTinkerLaunch") return true;
            }
            return false;
        }

        public override bool is_used () {
            return group.launcher.get_compatibility_tool_usage_count ("Proton-stl") > 0;
        }
    }
}