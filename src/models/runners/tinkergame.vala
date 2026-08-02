namespace ProtonPlus.Models.Runners {
    public class TinkerGame : Runner {
        public TinkerGame (Models.Group group) {
            Object (group: group,
                    title: "TinkerGame",
                    description: _ ("Steam tool for easy, graphical configuration of your other compatibility tools for both Windows games and native Linux games. A community fork of SteamTinkerLaunch."));
        }

        public override async ReturnCode load (out List<Models.Release> releases) {
            releases = new List<Models.Release> ();

            var release = new Releases.TinkerGame (this);

            releases.append (release);

            return ReturnCode.RELEASES_LOADED;
        }
    }
}
