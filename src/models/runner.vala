namespace ProtonPlus.Models {
    public class Runner : Object {
        public string title { get; set; }
        public string description { get; set; }
        public string endpoint { get; set; } // For GitHub Actions repository, make this the workflow url. See Proton Tkg for an example.
        public int asset_position { get; set; } // The position of the .tar.xz file in the json tree of the tool > assets
        public title_types title_type { get; set; }
        public endpoint_types endpoint_type { get; set; }

        public int old_asset_location { get; set; } // When the assets changes
        public int old_asset_position { get; set; } // Same as asset_position, but for older releases that might have different assets position

        public bool is_using_github_actions { get; set; }
        public bool use_name_instead_of_tag_name { get; set; }
        public bool api_error { get; set; }
        public string[] request_asset_exclude { get; set; }

        public uint page { get; set; }

        public Models.Group group { get; set; }

        public bool loaded { get; set; }
        public List<Models.Release> releases;

        public bool installed_loaded { get; set; }
        public List<Models.Release> installed_releases;

        public Runner (Models.Group group, string title, string description, string endpoint, int asset_position, title_types title_type) {
            this.page = 1;

            this.group = group;
            this.title = title;
            this.description = description;
            this.endpoint = endpoint;
            this.asset_position = asset_position;
            this.title_type = title_type;
            this.endpoint_type = endpoint_types.GITHUB;

            this.old_asset_location = -1;
            this.old_asset_position = -1;

            this.is_using_github_actions = false;
            this.use_name_instead_of_tag_name = false;
            this.api_error = false;
            this.loaded = false;

            this.releases = new List<Release> ();
        }

        public enum title_types {
            NONE,
            RELEASE_NAME,
            TOOL_NAME,
            STEAM_PROTON_GE,
            STEAM_TINKER_LAUNCH,
            PROTON_TKG,
            KRON4EK_VANILLA,
            KRON4EK_STAGING,
            KRON4EK_STAGING_TKG,
            DXVK,
            DXVK_ASYNC_SPORIF,
            LUTRIS_DXVK_ASYNC_GNUSENPAI,
            LUTRIS_DXVK_GPLASYNC,
            LUTRIS_WINE_GE,
            LUTRIS_WINE,
            LUTRIS_VKD3D,
            LUTRIS_VKD3D_PROTON,
            HGL_PROTON_GE,
            HGL_WINE_GE,
            HGL_VKD3D,
            BOTTLES,
            BOTTLES_PROTON_GE,
            BOTTLES_WINE_GE,
            BOTTLES_WINE_LUTRIS
        }

        public enum endpoint_types {
            GITHUB,
            GITLAB
        }

        public void load (bool installed_only) {
            if (title == "SteamTinkerLaunch") {
                loaded = true;
                return;
            }

            new Thread<void> ("load", () => {
                if (installed_only) {
                    installed_loaded = false;
                    load_installed ();
                } else {
                    loaded = false;
                    load_all ();
                };
            });
        }

        void load_installed () {
            installed_releases = new List<Models.Release> ();

            var dir = Posix.opendir (group.launcher.directory + group.directory);
            if (dir == null) {
                return;
            }

            unowned Posix.DirEnt? cur_d;

            while ((cur_d = Posix.readdir (dir)) != null) {
                // Skip hidden files and directories (".", ".." and leading ".foo").
                if (cur_d.d_name[0] == '.') {
                    continue;
                }

                string old_title = (string) cur_d.d_name;
                string title = Models.Release.get_directory_name_reverse (this, old_title);
                var release = new Models.Release (this, title, "", "", "", "", 0, "");

                if (old_title == release.get_directory_name ()) {
                    installed_releases.append (release);
                }
            }

            installed_releases.reverse ();

            installed_loaded = true;
        }

        void load_all () {
            Utils.Web.GET.begin (endpoint + "?per_page=25&page=" + page++.to_string (), false, (obj, res) => {
                string? json = Utils.Web.GET.end (res);

                if (json == null || json.contains ("https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting")) {
                    api_error = true;
                    return;
                }

                Json.Node? node = Utils.Parser.get_node_from_json (json);

                if (node == null)return;

                switch (endpoint_type) {
                    case endpoint_types.GITHUB :
                        if (is_using_github_actions) {
                            load_github_action (node);
                        } else {
                            load_github (node);
                        }
                        break;
                    case endpoint_types.GITLAB :
                        load_gitlab (node);
                        break;
                }

                loaded = true;
            });
        }

        void load_github_action (Json.Node rootNode) {
            var rootObj = rootNode.get_object ();

            if (!rootObj.has_member ("workflow_runs"))return;
            if (rootObj.get_member ("workflow_runs").get_node_type () != Json.NodeType.ARRAY)return;

            var workflowsRunArray = rootObj.get_array_member ("workflow_runs");
            if (workflowsRunArray == null)return;

            // Execute a loop with the number of items contained in the Version array and fill it
            for (var i = 0; i < workflowsRunArray.get_length (); i++) {
                string name = "";
                string status = "";
                string conclusion = "";
                string run_id = "";
                string html_url = "";
                string release_date = "";
                string artifacts_url = "";

                // Get the current node
                var tempNode = workflowsRunArray.get_element (i);
                var tempObject = tempNode.get_object ();

                status = tempObject.get_string_member ("status");
                conclusion = tempObject.get_string_member ("conclusion");
                run_id = tempObject.get_int_member ("id").to_string ();
                name = tempObject.get_int_member ("run_number").to_string ();
                html_url = tempObject.get_string_member ("html_url");
                release_date = tempObject.get_string_member ("created_at").split ("T")[0];
                artifacts_url = tempObject.get_string_member ("artifacts_url");

                if (status == "completed" && conclusion == "success") {
                    var release = new Release (this, name, @"https://nightly.link/Frogging-Family/wine-tkg-git/actions/runs/$run_id/proton-tkg-build.zip", html_url, release_date, "", -1, ".zip");
                    release.artifacts_url = artifacts_url;
                    releases.append (release);
                }
            }
        }

        void load_github (Json.Node rootNode) {
            // Get the root node from the json
            if (rootNode.get_node_type () != Json.NodeType.ARRAY)return;

            // Get the root node array
            var rootNodeArray = rootNode.get_array ();
            if (rootNodeArray == null)return;

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
                if (use_name_instead_of_tag_name)tag = objRoot.get_string_member ("name");
                else tag = objRoot.get_string_member ("tag_name");

                //
                var excluded = false;
                if (request_asset_exclude != null) {
                    foreach (var excluded_asset in request_asset_exclude) {
                        if (tag.contains (excluded_asset))excluded = true;
                    }
                }

                // FIXME Problem in the json (json_array_get_element: assertion 'index_ < array->elements->len' failed)
                if (!excluded) {
                    // Set the value of page_url to the html_url object contained in the current node
                    page_url = objRoot.get_string_member ("html_url");

                    release_date = objRoot.get_string_member ("created_at").split ("T")[0];

                    // Get the temp node array for the assets
                    var tempNodeArray = objRoot.get_array_member ("assets");

                    int pos = releases.length () >= old_asset_location ? old_asset_position : asset_position;

                    // Verify weither the temp node array has values
                    if (tempNodeArray.get_length () - 1 >= pos) {
                        var tempNodeArrayAsset = tempNodeArray.get_element (pos);
                        var objAsset = tempNodeArrayAsset.get_object ();

                        download_url = objAsset.get_string_member ("browser_download_url"); // Set the value of download_url to the browser_download_url object contained in the current node
                        download_size = objAsset.get_int_member ("size");

                        releases.append (new Release (this, tag, download_url, page_url, release_date, checksum_url, download_size, ".tar.gz")); // Currently here to prevent showing release with an invalid download_url
                    }
                }
            }
        }

        void load_gitlab (Json.Node rootNode) {
            // Get the root node from the json
            if (rootNode.get_node_type () != Json.NodeType.ARRAY)return;

            // Get the root node array
            var rootNodeArray = rootNode.get_array ();
            if (rootNodeArray == null)return;

            // Execute a loop with the number of items contained in the Version array and fill it
            for (var i = 0; i < rootNodeArray.get_length (); i++) {
                string tag = "";
                string download_url = "";
                string page_url = "";
                string release_date = "";
                string checksum_url = "";
                int64 download_size = -1;

                // Get the current node
                var tempNode = rootNodeArray.get_element (i);
                var objRoot = tempNode.get_object ();

                // Set the value of tag to the tag_name object contained in the current node
                if (use_name_instead_of_tag_name)tag = objRoot.get_string_member ("name");
                else tag = objRoot.get_string_member ("tag_name");

                //
                var excluded = false;
                if (request_asset_exclude != null) {
                    foreach (var excluded_asset in request_asset_exclude) {
                        if (tag.contains (excluded_asset))excluded = true;
                    }
                }

                //
                if (!excluded) {
                    // Set the value of page_url to the html_url object contained in the current node
                    var pageUrlNode = objRoot.get_member ("_links");
                    var pageUrlObjAsset = pageUrlNode.get_object ();
                    page_url = pageUrlObjAsset.get_string_member ("self");

                    //
                    release_date = objRoot.get_string_member ("created_at").split ("T")[0];

                    // Get the temp node array for the assets
                    var assetsNode = objRoot.get_member ("assets");
                    var assetsObjAsset = assetsNode.get_object ();

                    // Get the temp node array for the assets
                    var linksNodeArray = assetsObjAsset.get_array_member ("links");

                    //
                    int pos = releases.length () >= old_asset_location ? old_asset_position : asset_position;

                    // Verify weither the temp node array has values
                    if (linksNodeArray.get_length () - 1 >= pos) {
                        var tempNodeArrayAsset = linksNodeArray.get_element (pos);
                        var objAsset = tempNodeArrayAsset.get_object ();

                        download_url = objAsset.get_string_member ("direct_asset_url"); // Set the value of download_url to the browser_download_url object contained in the current node
                        download_url = download_url.replace ("?ref_type=heads", "");

                        releases.append (new Release (this, tag, download_url, page_url, release_date, checksum_url, download_size, ".tar.gz")); // Currently here to prevent showing release with an invalid download_url
                    }
                }
            }
        }
    }
}