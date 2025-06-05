namespace ProtonPlus.Models.Runners {
    public class SteamTinkerLaunch : Runner {
        public SteamTinkerLaunch (Models.Group group) {
            Object (group: group,
                    title: "Steam Tinker Launch",
                    description: _("Steam tool for easy, graphical configuration of your other compatibility tools for both Windows games and native Linux games."));
        }

        public override async List<Models.Release> load () {
            releases = new List<Models.Release> ();

            var release = new Releases.SteamTinkerLaunch (this);

            releases.append (release);

            return (owned) releases;
        }
    }
}