namespace ProtonPlus.Runners {
    public class SteamTinkerLaunch : Models.Runner {
        public SteamTinkerLaunch (Models.Group group) {
            Object (group: group,
                    title: "SteamTinkerLaunch",
                    description: _("Steam tool for easy, graphical configuration of your other compatibility tools for both Windows games and native Linux games."));
        }

        public override async List<Models.Release> load () {
            releases = new List<Models.Release> ();

            var temp_release = new List<Models.Release> ();

            var release = new Releases.SteamTinkerLaunch (this);
            releases.append (release);
            temp_release.append (release);

            return temp_release;
        }
    }
}