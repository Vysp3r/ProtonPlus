namespace ProtonPlus.Models.Runners {
    public class Northstar_Proton : GitHub {
        public Northstar_Proton (Group group) {
            Object (group: group,
                    title: "NorthstarProton",
                    description: _("Custom Proton build for running the Northstar client for Titanfall 2."),
                    endpoint: "https://api.github.com/repos/cyrv6737/NorthstarProton/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            return @"$title $release_name";
        }
    }
}