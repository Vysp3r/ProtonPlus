namespace ProtonPlus.Models.Launchers.Runners {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public enum SourceType {
        GITHUB,
        GITHUB_ACTION,
        GITLAB,
        FORGEJO,
    }

    public abstract class Base : Object, IRunner {
        public string title { get; set; }
        public string description { get; set; }
        public string endpoint { get; set; }

        public Gee.LinkedList<Variant> variants { get; set; default = new Gee.LinkedList<Variant> (); }
        public Gee.LinkedList<Launcher> launchers { get; set; default = new Gee.LinkedList<Launcher> (); }
        public SourceType source_type { get; protected set; }

        protected int asset_position { get; set; default = 0; }
        protected string asset_position_time_condition { get; set; default = ""; }
        protected bool support_latest { get; set; default = false; }
        protected string tag { get; set; default = ""; }
        protected bool legacy { get; set; default = false; }
        protected string url_template { get; set; default = ""; }
        protected Gee.ArrayList<string>? request_asset_filter { get; set; default = null; }
        protected Gee.ArrayList<string>? request_asset_exclude { get; set; default = null; }

        private Gee.HashMap<string, string> directory_name_formats = new Gee.HashMap<string, string> ();

        protected Base (SourceType source_type, string title, string description, string endpoint) {
            this.source_type = source_type;
            this.title = title;
            this.description = description;
            this.endpoint = endpoint;

            this.variants = new Gee.LinkedList<Variant> ();
            this.launchers = new Gee.LinkedList<Launcher> ();
        }

        protected void add_variant (string name, string format, bool is_default) {
            this.variants.add (new Variant (name, format, is_default));
        }

        protected void add_directory_name_format (string launcher, string directory_name_format) {
            this.directory_name_formats.set (launcher, directory_name_format);
        }

        protected string? get_directory_name_format (string launcher_title) {
            var target_format = this.directory_name_formats.get (launcher_title);
            if (target_format != null)
                return target_format;

            return this.directory_name_formats.get ("default");
        }

        public abstract async IReleases? request_releases (int page, int limit, out ReturnCode code);

        public Tools.Basic? create_tool (Group group) {
            string? target_format = get_directory_name_format (group.launcher.title);
            if (target_format == null)
                return null;

            Tools.Basic? runner = null;

            switch (source_type) {
            case SourceType.GITHUB:
                var github = new Tools.GitHub ();
                if (request_asset_exclude != null)
                    github.request_asset_exclude = request_asset_exclude.to_array ();
                if (request_asset_filter != null)
                    github.request_asset_filter = request_asset_filter.to_array ();
                runner = github;
                break;
            case SourceType.GITHUB_ACTION:
                var github_action = new Tools.GitHubAction ();
                github_action.url_template = url_template;
                runner = github_action;
                break;
            case SourceType.GITLAB:
                var gitlab = new Tools.GitLab ();
                if (request_asset_exclude != null)
                    gitlab.request_asset_exclude = request_asset_exclude.to_array ();
                runner = gitlab;
                break;
            case SourceType.FORGEJO:
                runner = new Tools.Forgejo ();
                break;
            }

            if (runner == null)
                return null;

            runner.title = this.title;
            runner.description = Utils.safe_translate (this.description);
            runner.endpoint = this.endpoint;
            runner.asset_position = this.asset_position;
            runner.asset_position_time_condition = this.asset_position_time_condition;
            runner.directory_name_format = target_format;
            runner.has_latest_support = this.support_latest;
            runner.group = group;
            runner.tag = this.tag;
            runner.legacy = this.legacy;
            runner.asset_position_hwcaps_condition = false;
            runner.source_runner = this;
            runner.variants = new Gee.LinkedList<ProtonPlus.Models.Variant> ();

            foreach (var variant_data in this.variants) {
                var variant = new ProtonPlus.Models.Variant (variant_data.name, variant_data.format, variant_data.is_default, runner);
                runner.variants.add (variant);
            }

            return runner;
        }
    }
}
