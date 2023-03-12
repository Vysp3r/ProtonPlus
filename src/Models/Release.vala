namespace Models {
    public class Release : Object, Interfaces.IModel {
        public string Title { get; set; }
        public string Download_URL;
        public string Release_Date;
        public string Checksum_URL;
        public string Page_URL;
        public int64 Download_Size;
        public string File_Extension;

        public Release (string title, string download_url = "", string page_url = "", string release_date = "", string checksum_url = "", int64 download_size = 0, string file_extension = ".tar.gz") {
            this.Title = title;
            this.Download_URL = download_url;
            this.Page_URL = page_url;
            this.File_Extension = file_extension;
            this.Release_Date = release_date;
            this.Download_Size = download_size;
            this.Checksum_URL = checksum_url;
        }

        public string GetFolderTitle (Models.Launcher launcher, Models.Tool tool) {
            switch (launcher.Title) {
            case "Heroic Games Launcher - Proton":
            case "Heroic Games Launcher - Proton (Flatpak)":
                return @"Proton-$Title";
            case "Heroic Games Launcher - Wine":
            case "Heroic Games Launcher - Wine (Flatpak)":
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

            return (owned) store;
        }

        public static List<Release> GetInstalled (Models.Launcher launcher) {
            List<Release> installedReleases = new List<Release> ();

            var folders = Utils.File.ListDirectoryFolders (launcher.Directory);

            folders.@foreach ((folder) => {
                installedReleases.append (new Release (folder));
            });

            return (owned) installedReleases;
        }

        public static GLib.List<Release> GetReleases (Models.Tool tool) {
            var releases = new GLib.List<Release> ();

            try {
                if (!tool.IsUsingGithubActions) {
                    // Get the json from the Tool endpoint
                    string json = Utils.Web.GET (tool.Endpoint);

                    // Get the root node from the json
                    var rootNode = Json.from_string (json);
                    if (rootNode == null) return releases;
                    if (rootNode.get_node_type () != Json.NodeType.ARRAY) return releases;

                    // Get the root node array
                    var rootNodeArray = rootNode.get_array ();
                    if (rootNodeArray == null) return releases;

                    // Execute a loop with the number of items contained in the Version array and fill it
                    for (var i = 0; i < rootNodeArray.get_length (); i++) {
                        string tag = "";
                        string download_url = "";
                        string page_url = "";
                        string release_date = "";
                        string checksum_url = "";
                        int64 download_size = 0;

                        // Get the current node
                        var tempNode = rootNodeArray.get_element (i);
                        var objRoot = tempNode.get_object ();

                        // Set the value of tag to the tag_name object contained in the current node
                        tag = objRoot.get_string_member ("tag_name");

                        // Set the value of page_url to the html_url object contained in the current node
                        page_url = objRoot.get_string_member ("html_url");

                        release_date = objRoot.get_string_member ("created_at").split ("T")[0];

                        // Get the temp node array for the assets
                        var tempNodeArray = objRoot.get_array_member ("assets");

                        // Verify weither the temp node array has values
                        if (tempNodeArray.get_length () >= tool.AssetPosition) {
                            var tempNodeArrayAssetTest = tempNodeArray.get_element (0);
                            var objAssetTest = tempNodeArrayAssetTest.get_object ();

                            checksum_url = objAssetTest.get_string_member ("browser_download_url");

                            var tempNodeArrayAsset = tempNodeArray.get_element (tool.AssetPosition);
                            var objAsset = tempNodeArrayAsset.get_object ();

                            download_url = objAsset.get_string_member ("browser_download_url"); // Set the value of download_url to the browser_download_url object contained in the current node
                            download_size = objAsset.get_int_member ("size");

                            releases.append (new Release (tag, download_url, page_url, release_date, checksum_url, download_size)); // Currently here to prevent showing release with an invalid download_url
                        }
                    }
                } else {
                    string json = Utils.Web.GET (tool.Endpoint);

                    var rootNode = Json.from_string (json);
                    if (rootNode == null) return releases;

                    var rootObj = rootNode.get_object ();

                    var workflowsRunArray = rootObj.get_array_member ("workflow_runs");
                    if (workflowsRunArray == null) return releases;

                    // Execute a loop with the number of items contained in the Version array and fill it
                    for (var i = 0; i < workflowsRunArray.get_length (); i++) {
                        string status = "";
                        string conclusion = "";
                        string run_id = "";
                        string html_url = "";

                        // Get the current node
                        var tempNode = workflowsRunArray.get_element (i);
                        var tempObject = tempNode.get_object ();

                        status = tempObject.get_string_member ("status");
                        conclusion = tempObject.get_string_member ("conclusion");
                        run_id = tempObject.get_int_member ("id").to_string ();
                        html_url = tempObject.get_string_member ("html_url");

                        if (status == "completed" && conclusion == "success") {
                            releases.append (new Release (run_id, @"https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/$run_id/proton-tkg-build.zip", html_url, ".zip"));
                        }
                    }
                }
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }

            return releases;
        }
    }
}
