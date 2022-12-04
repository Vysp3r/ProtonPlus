namespace ProtonPlus.Models {
    public class Release : Object, Interfaces.IModel {
        public string Title { get; set; }
        public string Tag;
        public string Download_URL;
        public string Page_URL;

        public Release (string title, string download_url = "", string page_url = "", string tag = "") {
            this.Title = title;
            this.Download_URL = download_url;
            this.Page_URL = page_url;
        }

        public string GetFolderTitle (Models.Launcher launcher, Models.Tool tool) {
            switch (launcher.Title) {
            case "Heroic Proton":
            case "Heroic Proton (Flatpak)":
                return @"Proton-$Title";
            case "Heroic Wine":
            case "Heroic Wine (Flatpak)":
                return @"Wine-$Title";
            default:
                switch (tool.Type) {
                case Models.Tool.TitleType.TOOL_NAME:
                    return tool.Title + @" $Title";
                default:
                    return Title;
                }
            }
        }

        public static GLib.ListStore GetStore (GLib.List<Release> releases) {
            var store = new GLib.ListStore (typeof (Release));

            foreach (var release in releases) {
                store.append (release);
            }

            return store;
        }

        public static List<Release> GetInstalled (Models.Launcher launcher) {
            List<Release> installedReleases = new List<Release> ();

            Posix.Dir dir = Posix.opendir (launcher.Directory);
            unowned Posix.DirEnt dirEnt;
            int count = 0;

            while ((dirEnt = Posix.readdir (dir)) != null) {
                if (count++ > 1 && dirEnt.d_type == 4) {
                    string name = (string) dirEnt.d_name;
                    installedReleases.append (new Release (name));
                }
            }

            return installedReleases;
        }

        public static GLib.List<Release> GetReleases (Models.Tool tool) {
            try {
                // Create a list of Release
                var releases = new GLib.List<Release> ();

                // Get the json from the Tool endpoint
                string json = Manager.HTTP.GET (tool.Endpoint);

                // Get the root node from the json
                var rootNode = Json.from_string (json);
                if (rootNode == null) return releases;
                if (rootNode.get_node_type () != Json.NodeType.ARRAY) return releases;

                // Get the root node array
                var rootNodeArray = rootNode.get_array ();
                if (rootNodeArray == null) return releases;

                // Execute a loop with the number of items contained in the Version array and fill it
                for (var i = 0; i < rootNodeArray.get_length (); i++) {
                    string title = "";
                    string tag = "";
                    string download_url = "";
                    string page_url = "";

                    // Get the current node
                    var tempNode = rootNodeArray.get_element (i);
                    var objRoot = tempNode.get_object ();

                    // Set the value of tag to the tag_name object contained in the current node
                    tag = objRoot.get_string_member ("tag_name");

                    // Set the value of page_url to the html_url object contained in the current node
                    page_url = objRoot.get_string_member ("html_url");

                    // Get the temp node array for the assets
                    var tempNodeArray = objRoot.get_array_member ("assets");

                    // Verify weither the temp node array has values
                    if (tempNodeArray.get_length () >= tool.AssetPosition) {
                        var tempNodeArrayAsset = tempNodeArray.get_element (tool.AssetPosition);
                        var objAsset = tempNodeArrayAsset.get_object ();
                        title = objAsset.get_string_member ("name").replace (".tar.xz", "").replace (".tar.gz", ""); // Set the value of title to the name object contained in the current node
                        download_url = objAsset.get_string_member ("browser_download_url"); // Set the value of download_url to the browser_download_url object contained in the current node
                        releases.append (new Release (tag, download_url, page_url, tag)); // Currently here to prevent showing release with an invalid download_url
                    }
                }

                // Return the Version array
                return releases;
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
                return new GLib.List<Release> ();
            }
        }
    }
}
