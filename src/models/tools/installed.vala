namespace ProtonPlus.Models.Tools {
    public class Installed : GitHub {
        // Installed tools are discovered from local data and therefore do not
        // mint a provider-definition identity.
        public Installed (Group group) {
            Object (group: group);
        }

        public override string get_directory_name (string release_name) {
            return release_name;
        }
    }
}
