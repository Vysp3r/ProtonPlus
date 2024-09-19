namespace ProtonPlus.Models.Runners {
    public class VKD3D_Lutris : GitHub {
        public VKD3D_Lutris (Group group) {
            Object (group: group,
                    title: "VKD3D-Lutris",
                    description: "",
                    endpoint: "https://api.github.com/repos/lutris/vkd3d/releases",
                    asset_position: 0);
        }

        public override string get_directory_name (string release_name) {
            switch (group.launcher.title) {
            case "Lutris":
                return release_name;
            case "Heroic Games Launcher":
                return release_name.replace ("v", "vkd3d-lutris-");
            default:
                return release_name;
            }
        }

        public override string get_directory_name_reverse (string release_name) {
            switch (group.launcher.title) {
            case "Lutris":
                if (release_name.contains ("vkd3d")) {
                    return "";
                }
                return release_name;
            case "Heroic Games Launcher":
                return release_name.replace ("vkd3d-lutris-", "v");
            default:
                return release_name;
            }
        }
    }
}