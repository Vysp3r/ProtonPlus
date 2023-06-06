namespace ProtonPlus.Shared.Models {
    public class Runner {
        public string title;
        public string description;
        public string endpoint; // For GitHub Actions repository, make this the workflow url. See Proton Tkg for an example.
        public int asset_position; // The position of the .tar.xz file in the json tree of the tool > assets
        public title_types title_type;

        public bool is_using_github_actions;
        public bool use_name_instead_of_tag_name;
        public bool is_using_cached_data;
        public string request_asset_exclude;
        public bool loaded;

        public Models.Group group;
        public List<Models.Release> releases;

        public Runner (Models.Group group, string title, string description, string endpoint, int asset_position, title_types title_type) {
            this.group = group;
            this.title = title;
            this.description = description;
            this.endpoint = endpoint;
            this.asset_position = asset_position;
            this.title_type = title_type;

            this.is_using_github_actions = false;
            this.use_name_instead_of_tag_name = false;
            this.is_using_cached_data = false;
            this.request_asset_exclude = "";
            this.loaded = false;
        }

        public enum title_types {
            RELEASE_NAME, // The title of the release only
            TOOL_NAME, // The title only shows the version number and need to have the tool name added before
            PROTON_HGL,
            WINE_HGL,
            BOTTLES,
            WINE_GE_BOTTLES,
            WINE_LUTRIS_BOTTLES,
            PROTON_TKG,
            LUTRIS_DXVK,
            LUTRIS_DXVK_ASYNC_SPORIF,
            LUTRIS_DXVK_ASYNC_GNUSENPAI,
            LUTRIS_WINE_GE,
            LUTRIS_WINE,
            LUTRIS_KRON4EK_VANILLA,
            LUTRIS_KRON4EK_TKG,
            NONE // Bypass and do not rename
        }

        public void load () {
            var releases = new GLib.List<Release> ();

            //
            string json = Utils.Web.GET (endpoint + "?per_page=25&page=1");

            //
            string base_path = GLib.Environment.get_user_data_dir () + "/ProtonPlus/";
            string path = base_path + title + ".json";

            //
            if (!GLib.FileUtils.test (base_path, GLib.FileTest.EXISTS)) Utils.Filesystem.CreateDirectory (base_path);

            //
            if (GLib.FileUtils.test (path, GLib.FileTest.EXISTS) && (json == "" || json.contains ("https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"))) {
                json = Utils.Filesystem.GetFileContent (path);
                is_using_cached_data = true;
            }

            //
            Json.Node rootNode;

            try {
                rootNode = Json.from_string (json);
            } catch (GLib.Error e) {
                message (e.message);
                return;
            }

            if (rootNode == null) return;

            //
            if (!is_using_github_actions) {
                // Get the root node from the json
                if (rootNode.get_node_type () != Json.NodeType.ARRAY) return;

                // Get the root node array
                var rootNodeArray = rootNode.get_array ();
                if (rootNodeArray == null) return;

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
                    if (use_name_instead_of_tag_name) tag = objRoot.get_string_member ("name");
                    else tag = objRoot.get_string_member ("tag_name");

                    //
                    if (!tag.contains (request_asset_exclude) || request_asset_exclude == "") {
                        // Set the value of page_url to the html_url object contained in the current node
                        page_url = objRoot.get_string_member ("html_url");

                        release_date = objRoot.get_string_member ("created_at").split ("T")[0];

                        // Get the temp node array for the assets
                        var tempNodeArray = objRoot.get_array_member ("assets");

                        // Verify weither the temp node array has values
                        if (tempNodeArray.get_length () >= asset_position) {
                            var tempNodeArrayAssetTest = tempNodeArray.get_element (0);
                            var objAssetTest = tempNodeArrayAssetTest.get_object ();

                            checksum_url = objAssetTest.get_string_member ("browser_download_url");

                            var tempNodeArrayAsset = tempNodeArray.get_element (asset_position);
                            var objAsset = tempNodeArrayAsset.get_object ();

                            download_url = objAsset.get_string_member ("browser_download_url"); // Set the value of download_url to the browser_download_url object contained in the current node
                            download_size = objAsset.get_int_member ("size");

                            releases.append (new Release (this, tag, download_url, page_url, release_date, checksum_url, download_size, ".tar.gz")); // Currently here to prevent showing release with an invalid download_url
                        }
                    }
                }
            } else {
                var rootObj = rootNode.get_object ();

                if (!rootObj.has_member ("workflow_runs")) return;
                if (rootObj.get_member ("workflow_runs").get_node_type () != Json.NodeType.ARRAY) return;

                var workflowsRunArray = rootObj.get_array_member ("workflow_runs");
                if (workflowsRunArray == null) return;

                // Execute a loop with the number of items contained in the Version array and fill it
                for (var i = 0; i < workflowsRunArray.get_length (); i++) {
                    string name = "";
                    string status = "";
                    string conclusion = "";
                    string run_id = "";
                    string html_url = "";
                    string release_date = "";

                    // Get the current node
                    var tempNode = workflowsRunArray.get_element (i);
                    var tempObject = tempNode.get_object ();

                    status = tempObject.get_string_member ("status");
                    conclusion = tempObject.get_string_member ("conclusion");
                    run_id = tempObject.get_int_member ("id").to_string ();
                    name = tempObject.get_int_member ("run_number").to_string ();
                    html_url = tempObject.get_string_member ("html_url");
                    release_date = tempObject.get_string_member ("created_at").split ("T")[0];;

                    if (status == "completed" && conclusion == "success") {
                        releases.append (new Release (this, name, @"https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/$run_id/proton-tkg-build.zip", html_url, release_date, "", -1, ".zip"));
                    }
                }
            }

            //
            if (GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) Utils.Filesystem.ModifyFile (path, json);
            else Utils.Filesystem.CreateFile (path, json);

            //
            loaded = true;

            //
            this.releases = (owned) releases;
        }
    }
}