namespace ProtonPlus.Models.Runners {
    public class Installed : GitHub {
        public Installed(Group group) {
            Object(group: group);
        }

        public override string get_directory_name(string release_name) {
            return release_name;
        }
    }
}