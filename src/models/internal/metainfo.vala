namespace ProtonPlus.Models.Internal {
    public class MetaInfo : Object {
        public string? id = null;
        public string? metadata_license = null;
        public string? project_license = null;
        public string? name = null;
        public string? summary = null;
        public string? description = null;
        public Gee.List<string> keywords;
        public Gee.List<MetaInfoRelease> releases;
        public Gee.List<AppStream.Screenshot> screenshots;
        public Gee.List<string> categories;
        public Gee.List<string> urls;

        public MetaInfo () {
            this.keywords = new Gee.ArrayList<string> ();
            this.categories = new Gee.ArrayList<string> ();
            this.urls = new Gee.ArrayList<string> ();
            this.screenshots = new Gee.ArrayList<AppStream.Screenshot> ();
            this.releases = new Gee.ArrayList<MetaInfoRelease> ();
        }

        public void add_release (string? version, string? date, string? description) {
            this.releases.add (new MetaInfoRelease () {
                version = version,
                date = date,
                description = description
            });
        }

        public MetaInfoRelease get_last_release () {
            return this.releases.first ();
        }

        public string get_full_change_log (int limit = 10) {
            var result = "";
            var last_release = get_last_release ();

            foreach (MetaInfoRelease item in this.releases.slice (0, limit)) {
                if (item.version == last_release.version) {
                    result += item.description + "\n";
                } else {
                    result += "<p>Version: " + item.version + "</p>\n";
                    result += item.description + "\n";
                }
            }

            return result;
        }
    }

    public class MetaInfoDeveloper : Object {
        public string? name = null;
    }

    public class MetaInfoScreenshot : Object {
        public string? type = null;
        public string? image = null;
        public string? caption = null;
    }

    public class MetaInfoRelease : Object {
        public string? version = null;
        public string? date = null;
        public string? description = null;
    }
}