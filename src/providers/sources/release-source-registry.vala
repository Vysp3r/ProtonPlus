namespace ProtonPlus.Providers.Sources {
    public class ReleaseSourceRegistry : Object {
        public static ReleaseSource? create (Models.Providers.SourceType source_type) {
            switch (source_type) {
            case Models.Providers.SourceType.GITHUB:
                return new GitHubReleaseSource ();
            case Models.Providers.SourceType.GITHUB_ACTIONS:
                return new GitHubActionsReleaseSource ();
            case Models.Providers.SourceType.GITLAB:
                return new GitLabReleaseSource ();
            case Models.Providers.SourceType.FORGEJO:
                return new ForgejoReleaseSource ();
            default:
                return null;
            }
        }
    }
}
