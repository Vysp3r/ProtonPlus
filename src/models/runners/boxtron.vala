namespace ProtonPlus.Models.Runners {
    public class Boxtron : GitHub {
        public Boxtron(Group group) {
            Object(group: group,
                   title: "Boxtron",
                   description: _("Steam compatibility tool for running DOS games using DOSBox for Linux."),
                   endpoint: "https://api.github.com/repos/dreamer/boxtron/releases",
                   asset_position: 0);
        }

        public override string get_directory_name(string release_name) {
            return @"$title $release_name";
        }

        public override string get_directory_name_reverse(string release_name) {
            return release_name.replace(title + " ", "");
        }
    }
}