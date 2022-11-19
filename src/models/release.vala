namespace ProtonPlus.Models {
    public class Release : Object {
        public string Label { public get; private set; }
        public string Download_URL { public get; private set; }
        public string Page_URL { public get; private set; }

        public Release (string label, string download_url, string page_url) {
            this.Label = label;
            this.Download_URL = download_url;
            this.Page_URL = page_url;
        }

        public static GLib.ListStore GetStore (GLib.List<Release> releases) {
            var store = new GLib.ListStore (typeof (Release));

            foreach (var release in releases) {
                 store.append (release);
            }

            return store;
        }

        public static List<Release> GetInstalled (ProtonPlus.Models.Location location) {
            List<Release> installedReleases = new List<Release> ();

            Posix.Dir dir = Posix.opendir (location.InstallDirectory);
            unowned Posix.DirEnt dirEnt;
            int count = 0;

            while ((dirEnt = Posix.readdir (dir)) != null) {
                if(count++ > 1 && dirEnt.d_type == 4) {
                    string name = (string) dirEnt.d_name;
                    installedReleases.append (new Release(name, "", ""));
                }
            }

            return installedReleases;
        }

        public static GLib.List<Release> GetReleases (string endpoint, int asset_position) {
            // Get the json from the Tool endpoint
            string json = ProtonPlus.Manager.HTTP.GET (endpoint);

            // Get the root node from the json
            Json.Node rootNode = Json.from_string (json);

            // Get the root node array
            Json.Array rootNodeArray = rootNode.get_array ();

            // Create an array of Version with the size of the root node array
            var releases = new GLib.List<Release> ();

            // Execute a loop with the number of items contained in the Version array and fill it
            for (var i = 0; i < rootNodeArray.get_length (); i++) {
                string label = "";
                string download_url = "";
                string page_url = "";

                // Get the current node
                var tempNode = rootNodeArray.get_element (i);
                Json.Object objRoot = tempNode.get_object ();

                // Set the value of label to the tag_name object contained in the current node
                label = objRoot.get_string_member ("tag_name");

                page_url = objRoot.get_string_member ("html_url");

                // Get the temp node array for the assets
                var tempNodeArray = objRoot.get_array_member ("assets");

                // Verify weither the temp node array has values and if so it set the endpoint to the given download url
                if (tempNodeArray.get_length () >= asset_position) {
                    var test = tempNodeArray.get_element (asset_position);
                    Json.Object objAsset = test.get_object ();
                    download_url = objAsset.get_string_member ("browser_download_url");
                    releases.append (new Release (label, download_url, page_url)); // Currently here to prevent showing release with an invalid download_url
                }
            }

            // Return the Version array
            return releases;
        }
    }
}
