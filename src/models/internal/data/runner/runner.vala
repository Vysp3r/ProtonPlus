using GLib;
using Gee;

namespace ProtonPlus.Models.Internal.Data.Runner {
    public class Runner : Object {
        public string title { get; set; }
        public string description { get; set; }
        public string endpoint { get; set; }
        public int asset_position { get; set; }
        public string? asset_position_time_condition { get; set; }
        public Gee.ArrayList<DirectoryNameFormat> directory_name_formats { get; set; }
        public Gee.ArrayList<RunnerVariant> variants { get; set; }
        public bool support_latest { get; set; }
        public string? tag { get; set; }
        [CCode (cname = "type")]
        public string runner_type { get; set; }

        public string? directory_name_format { get; set; }
        public string? url_template { get; set; }
        public bool legacy { get; set; }
        public Gee.ArrayList<string>? request_asset_exclude { get; set; }
        public Gee.ArrayList<string>? request_asset_filter { get; set; }

        public Runner () {
            this.directory_name_formats = new Gee.ArrayList<DirectoryNameFormat> ();
            this.variants = new Gee.ArrayList<RunnerVariant> ();
        }
    }

    public class RunnerVariant : Object {
        public string name { get; set; }
        public string format { get; set; }
        public bool? is_default { get; set; }
    }
}
