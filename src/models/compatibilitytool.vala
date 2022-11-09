namespace ProtonPlus.Models {
    public class CompatibilityTool : Object {

        public string Title { public get; private set; }
        public string Description { public get; private set; }
        public string Endpoint { public get; private set; }
        public int AssetPosition { public get; private set; }

        public CompatibilityTool (string title, string description, string endpoint, int asset_position) {
            this.Title = title;
            this.Description = description;
            this.Endpoint = endpoint;
            this.AssetPosition = asset_position;
        }

        public GLib.List<Release> GetReleases () {
            // Get the json from the Tool endpoint
            string json = ProtonPlus.Manager.HTTP.GET (Endpoint);

            // Get the root node from the json
            Json.Node rootNode = Json.from_string (json);

            // Get the root node array
            Json.Array rootNodeArray = rootNode.get_array ();

            // Create an array of Version with the size of the root node array
            GLib.List<Release> releases = new GLib.List<Release> ();

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
                if (tempNodeArray.get_length () >= AssetPosition) {
                    var test = tempNodeArray.get_element (AssetPosition);
                    Json.Object objAsset = test.get_object ();
                    download_url = objAsset.get_string_member ("browser_download_url");
                    releases.append (new Release (label, download_url, page_url)); // Currently here to prevent showing release with an invalid download_url
                }
            }

            // Return the Version array
            return releases;
        }

        public static GLib.ListStore GetStore (CompatibilityTool[] tools) {
            var store = new GLib.ListStore (typeof (CompatibilityTool));

            foreach (var tool in tools) {
                store.append (tool);
            }

            return store;
        }

        public static GLib.ListStore GetReleasesStore (GLib.List<Release> releases) {
            var store = new GLib.ListStore (typeof (Release));

            foreach (var release in releases) {
                 store.append (release);
            }

            return store;
        }

        public class Release : Object {
            public string Label { public get; private set; }
            public string Download_URL { public get; private set; }
            public string Page_URL { public get; private set; }

            public Release (string label, string download_url, string page_url) {
                this.Label = label;
                this.Download_URL = download_url;
                this.Page_URL = page_url;
            }

            public static GLib.ListStore GetModel (List<Release> releases) {
                GLib.ListStore model = new GLib.ListStore (typeof (Release));

                foreach (var item in releases) {
                    model.append (item);
                }

                return model;
            }
        }

        public static CompatibilityTool[] Steam () {
            CompatibilityTool[] tools = new CompatibilityTool[5];

            tools[0] = new CompatibilityTool ("GE-Proton", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1);
            tools[1] = new CompatibilityTool ("Proton Tkg", "Custom Proton build for running Windows games, built with the Wine-tkg build system.", "https://api.github.com/repos/Frogging-Family/wine-tkg-git/releases", 1);
            tools[2] = new CompatibilityTool ("Luxtorpeda", "Luxtorpeda provides Linux-native game engines for specific Windows-only games.", "https://api.github.com/repos/luxtorpeda-dev/luxtorpeda/releases", 0);
            tools[3] = new CompatibilityTool ("Boxtron", "Steam Play compatibility tool to run DOS games using native Linux DOSBox.", "https://api.github.com/repos/dreamer/boxtron/releases", 0);
            tools[4] = new CompatibilityTool ("Roberta", "Steam Play compatibility tool to run adventure games using native Linux ScummVM.", "https://api.github.com/repos/dreamer/roberta/releases", 1);

            return tools;
        }

        public static CompatibilityTool[] Lutris () {
            CompatibilityTool[] tools = new CompatibilityTool[3];

            tools[0] = new CompatibilityTool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1);
            tools[1] = new CompatibilityTool ("Lutris-Wine", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0);
            tools[2] = new CompatibilityTool ("Kron4ek Wine-Builds Vanilla", "Compatibility tool \"Wine\" to run Windows games on Linux. Official version from the WineHQ sources, compiled by Kron4ek.", "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 5);
            return tools;
        }

        public static CompatibilityTool[] LutrisDXVK () {
            CompatibilityTool[] tools = new CompatibilityTool[3];

            tools[0] = new CompatibilityTool ("DXVK", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine.https://github.com/lutris/docs/blob/master/HowToDXVK.md", "https://api.github.com/repos/doitsujin/dxvk/releases", 0);
            tools[1] = new CompatibilityTool ("DXVK Async (Sporif)", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch by Sporif.Warning: Use only with singleplayer games!", "https://api.github.com/repos/Sporif/dxvk-async/releases", 0);
            tools[2] = new CompatibilityTool ("DXVK Async (gnusenpai)", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch and RTX fix for Star Citizen by gnusenpai.Warning: Use only with singleplayer games!", "https://api.github.com/repos/gnusenpai/dxvk/releases", 0);

            return tools;
        }

        public static CompatibilityTool[] HeroicWine () {
            CompatibilityTool[] tools = new CompatibilityTool[1];

            tools[0] = new CompatibilityTool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1);

            return tools;
        }

        public static CompatibilityTool[] HeroicProton () {
            CompatibilityTool[] tools = new CompatibilityTool[1];

            tools[0] = new CompatibilityTool ("GE-Proton", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1);

            return tools;
        }

        public static CompatibilityTool[] Bottles () {
            CompatibilityTool[] tools = new CompatibilityTool[3];

            tools[0] = new CompatibilityTool ("GE-Proton", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1);
            tools[1] = new CompatibilityTool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1);
            tools[2] = new CompatibilityTool ("Lutris-Wine", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0);

            return tools;
        }

        public static List<Release> Installed (ProtonPlus.Models.Location location) {
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
    }
}
