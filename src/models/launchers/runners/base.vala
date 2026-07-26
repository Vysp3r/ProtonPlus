namespace ProtonPlus.Models.Launchers.Runners {
    using Gee;
    using ProtonPlus.Providers.Sources;

    public enum SourceType {
        GITHUB,
        GITHUB_ACTION,
        GITLAB,
        FORGEJO,
    }

    public abstract class Base : Object, IRunner {
        private string _provider_id = "";
        private string _source_id = "";

        public string provider_id {
            get { return _provider_id; }
            set {
                if (_provider_id == "")
                    _provider_id = value;
            }
        }
        public string source_id {
            get { return _source_id; }
            set {
                if (_source_id == "")
                    _source_id = value;
            }
        }
        public string title { get; set; }
        public string description { get; set; }
        public string endpoint { get; set; }
        public int sort_priority { get; set; default = 1000; }

        public Gee.LinkedList<Variant> variants { get; set; default = new Gee.LinkedList<Variant> (); }
        public Gee.LinkedList<Launcher> launchers { get; set; default = new Gee.LinkedList<Launcher> (); }
        public SourceType source_type { get; protected set; }

        protected string tag { get; set; default = ""; }
        protected bool legacy { get; set; default = false; }
        protected string url_template { get; set; default = ""; }
        protected Gee.ArrayList<string>? request_asset_filter { get; set; default = null; }
        protected Gee.ArrayList<string>? request_asset_exclude { get; set; default = null; }

        private Gee.HashMap<string, string> directory_name_formats = new Gee.HashMap<string, string> ();

        protected Base (SourceType source_type, string provider_id, string title, string description, string endpoint) {
            this.source_type = source_type;
            this.provider_id = provider_id;
            this.source_id = get_source_id (source_type);
            this.title = title;
            this.description = description;
            this.endpoint = endpoint;

            this.variants = new Gee.LinkedList<Variant> ();
            this.launchers = new Gee.LinkedList<Launcher> ();
        }

        private static string get_source_id (SourceType source_type) {
            switch (source_type) {
            case SourceType.GITHUB:
                return "github";
            case SourceType.GITHUB_ACTION:
                return "github-actions";
            case SourceType.GITLAB:
                return "gitlab";
            case SourceType.FORGEJO:
                return "forgejo";
            default:
                return "";
            }
        }

        protected void add_variant (string id, string name, string format, bool is_default) {
            this.variants.add (new Variant (id, name, format, is_default));
        }

        protected void add_directory_name_format (string launcher_family_id, string directory_name_format) {
            this.directory_name_formats.set (launcher_family_id, directory_name_format);
        }

        protected string? get_directory_name_format (string launcher_family_id) {
            var target_format = this.directory_name_formats.get (launcher_family_id);
            if (target_format != null)
                return target_format;

            return this.directory_name_formats.get ("default");
        }

        public abstract async IReleases? request_releases (int page, int limit, out ReturnCode code);

        public Tools.Basic? create_tool (Group group) {
            string? target_format = get_directory_name_format (group.launcher.family_id);
            if (target_format == null)
                return null;

            Tools.Basic? runner = null;

            switch (source_type) {
            case SourceType.GITHUB:
                var github = new ProtonPlus.Providers.Normalizers.GitHub ();
                if (request_asset_exclude != null)
                    github.request_asset_exclude = request_asset_exclude.to_array ();
                if (request_asset_filter != null)
                    github.request_asset_filter = request_asset_filter.to_array ();
                runner = github;
                break;
            case SourceType.GITHUB_ACTION:
                var github_action = new ProtonPlus.Providers.Normalizers.GitHubAction ();
                github_action.url_template = url_template;
                runner = github_action;
                break;
            case SourceType.GITLAB:
                var gitlab = new ProtonPlus.Providers.Normalizers.GitLab ();
                if (request_asset_exclude != null)
                    gitlab.request_asset_exclude = request_asset_exclude.to_array ();
                runner = gitlab;
                break;
            case SourceType.FORGEJO:
                runner = new ProtonPlus.Providers.Normalizers.Forgejo ();
                break;
            }

            if (runner == null)
                return null;

            runner.title = this.title;
            runner.description = Utils.safe_translate (this.description);
            runner.endpoint = this.endpoint;
            runner.directory_name_format = target_format;
            runner.group = group;
            runner.tag = this.tag;
            runner.legacy = this.legacy;
            runner.sort_priority = this.sort_priority;
            runner.source_runner = this;
            runner.set_identity (provider_id, source_id);
            runner.variants = new Gee.LinkedList<ProtonPlus.Models.Variant> ();

            foreach (var variant_data in this.variants) {
                var variant = new ProtonPlus.Models.Variant (
                    variant_data.id,
                    variant_data.name,
                    variant_data.format,
                    variant_data.is_default,
                    null
                );
                runner.variants.add (variant);
            }

            return runner;
        }
    }
}
