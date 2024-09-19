namespace ProtonPlus.Models.Runners {
    public class Other : GitHub {
        public Other (Models.Group group) {
            Object (group: group, title: "Other", description: _(""),
                    endpoint: "https://api.github.com/repos/bottlesdevs/wine/releases",
                    asset_position: 0,
                    use_name_instead_of_tag_name: true);
        }

        public override string get_directory_name (string release_name) {
            return release_name.down ().replace (" ", "-");
        }

        public override string get_directory_name_reverse (string release_name) {
            if (release_name.contains ("soda")) {
                var parts = release_name.split ("-");
                var start = parts[0].substring (1);
                return parts[0][0].to_string ().up () + start + " " + parts[1] + "-" + parts[2];
            }

            var parts = release_name.split ("-");
            var start = parts[0].substring (1);
            return parts[0][0].to_string ().up () + start + " " + parts[1];
        }
    }
}