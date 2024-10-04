namespace ProtonPlus.Models.Runners {
    public class Roberta : GitHub {
        public Roberta (Group group) {
            Object (group: group,
                    title: "Roberta",
                    description: _("Steam compatibility tool for running adventure games using ScummVM for Linux."),
                    endpoint: "https://api.github.com/repos/dreamer/roberta/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            return @"$title $release_name";
        }

        public override string get_directory_name_reverse (string release_name) {
            return release_name.replace (title + " ", "");
        }
    }
}