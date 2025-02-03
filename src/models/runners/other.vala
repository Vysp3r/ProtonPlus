namespace ProtonPlus.Models.Runners {
    public class Other : GitHub {
        public Other (Group group) {
            Object (group: group,
                    title: "Other",
                    description: "",
                    endpoint: "https://api.github.com/repos/bottlesdevs/wine/releases",
                    asset_position: 0,
                    use_name_instead_of_tag_name: true);
        }

        public override string get_directory_name (string release_name) {
            return release_name.down ().replace (" ", "-");
        }
    }
}