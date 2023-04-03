namespace Models {
    public class Tool : Object {
        public string Title;
        public string Description;
        public string Website;
        public string Endpoint; // For GitHub Actions repository, make this the workflow url. See Proton Tkg for an example.
        public int AssetPosition; // The position of the .tar.xz file in the json tree of the tool > assets
        public TitleTypes TitleType;
        public bool IsUsingGithubActions;
        public bool useNameInsteadOfTagName;
        public Models.Launcher Launcher;
        public List<Models.Release> Releases;

        public Tool (Models.Launcher launcher, string title, string description, string endpoint, int asset_position, TitleTypes type = TitleTypes.NONE, bool isUsingGithubActions = false) {
            Launcher = launcher;
            Title = title;
            Description = description;
            Endpoint = endpoint;
            AssetPosition = asset_position;
            TitleType = type;
            IsUsingGithubActions = isUsingGithubActions;
            useNameInsteadOfTagName = false;
            Website = "";
        }

        public enum TitleTypes {
            RELEASE_NAME, // The title of the release only
            TOOL_NAME, // The title only shows the version number and need to have the tool name added before
            PROTON_HGL, // A custom title specfic to Heroic Games Launcher Proton
            WINE_HGL, // A custom title specfic to Heroic Games Launcher Wine
            BOTTLES, // A custom title specfic to Bottles
            WINE_GE_BOTTLES, // A custom title specfic to Bottles
            WINE_LUTRIS_BOTTLES, // A custom title specfic to Bottles
            PROTON_TKG, //
            LUTRIS_DXVK, //
            LUTRIS_DXVK_ASYNC_SPORIF, //
            LUTRIS_DXVK_ASYNC_GNUSENPAI, //
            LUTRIS_WINE_GE, //
            LUTRIS_WINE, //
            LUTRIS_KRON4EK, //
            NONE // Bypass and do not rename
        }

        public static GLib.List<Tool> Steam (Models.Launcher launcher) {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool (launcher, "Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1));
            tools.append (new Tool (launcher, "Luxtorpeda", "Luxtorpeda provides Linux-native game engines for specific Windows-only games.", "https://api.github.com/repos/luxtorpeda-dev/luxtorpeda/releases", 0, TitleTypes.TOOL_NAME));
            tools.append (new Tool (launcher, "Boxtron", "Steam Play compatibility tool to run DOS games using native Linux DOSBox.", "https://api.github.com/repos/dreamer/boxtron/releases", 0, TitleTypes.TOOL_NAME));
            tools.append (new Tool (launcher, "Roberta", "Steam Play compatibility tool to run adventure games using native Linux ScummVM.", "https://api.github.com/repos/dreamer/roberta/releases", 0, TitleTypes.TOOL_NAME));
            tools.append (new Tool (launcher, "NorthstarProton", "Custom Proton build for running the Northstar client for Titanfall 2.", "https://api.github.com/repos/cyrv6737/NorthstarProton/releases", 0, TitleTypes.TOOL_NAME));
            tools.append (new Tool (launcher, "Proton Tkg", "Custom Proton build for running Windows games, built with the Wine-tkg build system.", "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/29873769/runs", 0, TitleTypes.PROTON_TKG, true));

            return tools;
        }

        public static GLib.List<Tool> Lutris (Models.Launcher launcher) {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool (launcher, "Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, LUTRIS_WINE_GE));
            tools.append (new Tool (launcher, "Wine-Lutris", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0, LUTRIS_WINE));
            tools.append (new Tool (launcher, "Kron4ek Wine-Builds Vanilla", "Compatibility tool \"Wine\" to run Windows games on Linux. Official version from the WineHQ sources, compiled by Kron4ek.", "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 1, LUTRIS_KRON4EK));

            return tools;
        }

        public static GLib.List<Tool> LutrisDXVK (Models.Launcher launcher) {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool (launcher, "DXVK", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine.https://github.com/lutris/docs/blob/master/HowToDXVK.md", "https://api.github.com/repos/doitsujin/dxvk/releases", 0, LUTRIS_DXVK));
            tools.append (new Tool (launcher, "DXVK Async (Sporif)", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch by Sporif.Warning: Use only with singleplayer games!", "https://api.github.com/repos/Sporif/dxvk-async/releases", 0, LUTRIS_DXVK_ASYNC_SPORIF));
            tools.append (new Tool (launcher, "DXVK Async (gnusenpai)", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch and RTX fix for Star Citizen by gnusenpai.Warning: Use only with singleplayer games!", "https://api.github.com/repos/gnusenpai/dxvk/releases", 0, LUTRIS_DXVK_ASYNC_GNUSENPAI));

            return tools;
        }

        public static GLib.List<Tool> HeroicWine (Models.Launcher launcher) {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool (launcher, "Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, TitleTypes.WINE_HGL));

            return tools;
        }

        public static GLib.List<Tool> HeroicProton (Models.Launcher launcher) {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool (launcher, "Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1, TitleTypes.PROTON_HGL));

            return tools;
        }

        public static GLib.List<Tool> Bottles (Models.Launcher launcher) {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool (launcher, "Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1, TitleTypes.BOTTLES));
            tools.append (new Tool (launcher, "Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, TitleTypes.WINE_GE_BOTTLES));
            tools.append (new Tool (launcher, "Wine-Lutris", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0, TitleTypes.WINE_LUTRIS_BOTTLES));

            var otherTool = new Tool (launcher, "Other", "", "https://api.github.com/repos/bottlesdevs/wine/releases", 0, TitleTypes.BOTTLES);
            otherTool.useNameInsteadOfTagName = true;
            tools.append (otherTool);

            return tools;
        }

        public static GLib.List<Tool> BottlesDXVK (Models.Launcher launcher) {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool (launcher, "DXVK", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine.https://github.com/lutris/docs/blob/master/HowToDXVK.md", "https://api.github.com/repos/doitsujin/dxvk/releases", 0, TitleTypes.BOTTLES));
            tools.append (new Tool (launcher, "DXVK Async", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch by Sporif.Warning: Use only with singleplayer games!", "https://api.github.com/repos/Sporif/dxvk-async/releases", 0, TitleTypes.BOTTLES));

            return tools;
        }

        public GLib.List<Release> GetReleases () {
            var releases = new GLib.List<Release> ();

            try {
                if (!IsUsingGithubActions) {
                    // Get the json from the Tool endpoint
                    string json = Utils.Web.GET (Endpoint);

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
                        if (useNameInsteadOfTagName) tag = objRoot.get_string_member ("name");
                        else tag = objRoot.get_string_member ("tag_name");

                        // Set the value of page_url to the html_url object contained in the current node
                        page_url = objRoot.get_string_member ("html_url");

                        release_date = objRoot.get_string_member ("created_at").split ("T")[0];

                        // Get the temp node array for the assets
                        var tempNodeArray = objRoot.get_array_member ("assets");

                        // Verify weither the temp node array has values
                        if (tempNodeArray.get_length () >= AssetPosition) {
                            var tempNodeArrayAssetTest = tempNodeArray.get_element (0);
                            var objAssetTest = tempNodeArrayAssetTest.get_object ();

                            checksum_url = objAssetTest.get_string_member ("browser_download_url");

                            var tempNodeArrayAsset = tempNodeArray.get_element (AssetPosition);
                            var objAsset = tempNodeArrayAsset.get_object ();

                            download_url = objAsset.get_string_member ("browser_download_url"); // Set the value of download_url to the browser_download_url object contained in the current node
                            download_size = objAsset.get_int_member ("size");

                            releases.append (new Release (this, tag, download_url, page_url, release_date, checksum_url, download_size)); // Currently here to prevent showing release with an invalid download_url
                        }
                    }
                } else {
                    string json = Utils.Web.GET (Endpoint);

                    var rootNode = Json.from_string (json);
                    if (rootNode == null) return releases;

                    var rootObj = rootNode.get_object ();

                    if (!rootObj.has_member ("workflow_runs")) return releases;
                    if (rootObj.get_member ("workflow_runs").get_node_type () != Json.NodeType.ARRAY) return releases;

                    var workflowsRunArray = rootObj.get_array_member ("workflow_runs");
                    if (workflowsRunArray == null) return releases;

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
            } catch (GLib.Error e) {
                stderr.printf (e.message + "\n");
            }

            return releases;
        }
    }
}
