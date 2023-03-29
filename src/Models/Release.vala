namespace Models {
    public class Release : Object {
        public Models.Tool Tool;
        public string Title;
        public string DownloadURL;
        public string ChecksumURL;
        public string PageURL;
        public string ReleaseDate;
        public int64 DownloadSize;
        public string FileExtension;
        public bool Installed;
        public string Directory;
        public int64 Size;

        public Release (Models.Tool tool, string title, string download_url = "", string page_url = "", string release_date = "", string checksum_url = "", int64 download_size = 0, string file_extension = ".tar.gz") {
            Tool = tool;
            Title = title;
            DownloadURL = download_url;
            PageURL = page_url;
            FileExtension = file_extension;
            ReleaseDate = release_date;
            DownloadSize = download_size;
            ChecksumURL = checksum_url;
            Directory = Tool.Launcher.FullPath + "/" + GetDirectoryName ();
            Installed = FileUtils.test (Directory, FileTest.IS_DIR);
            Size = 0;

            if (Installed) {
                var dirUtil = new Utils.DirUtil (Directory);
                Size = (int64) dirUtil.get_total_size ();
            }
        }

        public string GetFormattedDownloadSize () {
            return Utils.File.BytesToString (DownloadSize);
        }

        public string GetFormattedSize () {
            return Utils.File.BytesToString (Size);
        }

        public string GetDirectoryName () {
            switch (Tool.TitleType) {
            case Models.Tool.TitleTypes.WINE_LUTRIS_BOTTLES:
                return Title.down ().replace ("-wine", "");
            case Models.Tool.TitleTypes.WINE_GE_BOTTLES:
                return "wine-" + Title.down ();
            case Models.Tool.TitleTypes.BOTTLES:
                return Title.down ().replace (" ", "-");
            case Models.Tool.TitleTypes.PROTON_HGL:
                return @"Proton-$Title";
            case Models.Tool.TitleTypes.WINE_HGL:
                return @"Wine-$Title";
            case Models.Tool.TitleTypes.TOOL_NAME:
                return Tool.Title + @" $Title";
            default:
                return Title;
            }
        }

        public async GLib.List<Release> GetReleases () {
            var releases = new GLib.List<Release> ();

            try {
                if (!Tool.IsUsingGithubActions) {
                    // Get the json from the Tool endpoint
                    string json = Utils.Web.GET (Tool.Endpoint);

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
                        if (Tool.useNameInsteadOfTagName) tag = objRoot.get_string_member ("name");
                        else tag = objRoot.get_string_member ("tag_name");

                        // Set the value of page_url to the html_url object contained in the current node
                        page_url = objRoot.get_string_member ("html_url");

                        release_date = objRoot.get_string_member ("created_at").split ("T")[0];

                        // Get the temp node array for the assets
                        var tempNodeArray = objRoot.get_array_member ("assets");

                        // Verify weither the temp node array has values
                        if (tempNodeArray.get_length () >= Tool.AssetPosition) {
                            var tempNodeArrayAssetTest = tempNodeArray.get_element (0);
                            var objAssetTest = tempNodeArrayAssetTest.get_object ();

                            checksum_url = objAssetTest.get_string_member ("browser_download_url");

                            var tempNodeArrayAsset = tempNodeArray.get_element (Tool.AssetPosition);
                            var objAsset = tempNodeArrayAsset.get_object ();

                            download_url = objAsset.get_string_member ("browser_download_url"); // Set the value of download_url to the browser_download_url object contained in the current node
                            download_size = objAsset.get_int_member ("size");

                            releases.append (new Release (Tool, tag, download_url, page_url, release_date, checksum_url, download_size)); // Currently here to prevent showing release with an invalid download_url
                        }
                    }
                } else {
                    string json = Utils.Web.GET (Tool.Endpoint);

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
                            releases.append (new Release (Tool, run_id, @"https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/$run_id/proton-tkg-build.zip", html_url, ".zip"));
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
