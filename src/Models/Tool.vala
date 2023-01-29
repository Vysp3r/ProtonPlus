namespace Models {
    public class Tool : Object, Interfaces.IModel {

        public string Title { get; set; }
        public string Description;
        public string Endpoint;
        public int AssetPosition; // The position of the .tar.xz file in the json tree of the tool > assets
        public TitleType Type;
        public bool IsActions;

        public Tool (string title, string description, string endpoint, int asset_position, TitleType type = TitleType.SIMPLE, bool isActions = false) {
            this.Title = title;
            this.Description = description;
            this.Endpoint = endpoint; // For GitHub Actions repository, make this the workflow url. See Proton Tkg for an example.
            this.AssetPosition = asset_position;
            this.Type = type;
            this.IsActions = isActions;
        }

        public enum TitleType {
            SIMPLE, // The title contains the version number and does not require any modification
            TOOL_NAME, // The title only shows the version number and need to have the tool name added before
            NONE // Bypass and do not rename
        }

        public static GLib.ListStore GetStore (GLib.List<Tool> tools) {
            var store = new GLib.ListStore (typeof (Tool));

            tools.@foreach ((tool) => {
                store.append (tool);
            });

            return (owned) store;
        }

        public static GLib.List<Tool> Steam () {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool ("Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1, TitleType.NONE));
            tools.append (new Tool ("Luxtorpeda", "Luxtorpeda provides Linux-native game engines for specific Windows-only games.", "https://api.github.com/repos/luxtorpeda-dev/luxtorpeda/releases", 0, TitleType.TOOL_NAME));
            tools.append (new Tool ("Boxtron", "Steam Play compatibility tool to run DOS games using native Linux DOSBox.", "https://api.github.com/repos/dreamer/boxtron/releases", 0, TitleType.TOOL_NAME));
            tools.append (new Tool ("Roberta", "Steam Play compatibility tool to run adventure games using native Linux ScummVM.", "https://api.github.com/repos/dreamer/roberta/releases", 0, TitleType.TOOL_NAME));
            tools.append (new Tool ("NorthstarProton", "Custom Proton build for running the Northstar client for Titanfall 2.", "https://api.github.com/repos/cyrv6737/NorthstarProton/releases", 0, TitleType.TOOL_NAME));
            tools.append (new Tool ("Proton Tkg", "Custom Proton build for running Windows games, built with the Wine-tkg build system.", "https://api.github.com/repos/Frogging-Family/wine-tkg-git/actions/workflows/29873769/runs", 0, TitleType.NONE, true));

            return tools;
        }

        public static GLib.List<Tool> Lutris () {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1, TitleType.NONE));
            tools.append (new Tool ("Wine-Lutris", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0, TitleType.NONE));
            tools.append (new Tool ("Kron4ek Wine-Builds Vanilla", "Compatibility tool \"Wine\" to run Windows games on Linux. Official version from the WineHQ sources, compiled by Kron4ek.", "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 1, TitleType.NONE));

            return tools;
        }

        public static GLib.List<Tool> LutrisDXVK () {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool ("DXVK", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine.https://github.com/lutris/docs/blob/master/HowToDXVK.md", "https://api.github.com/repos/doitsujin/dxvk/releases", 0, TitleType.NONE));
            tools.append (new Tool ("DXVK Async (Sporif)", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch by Sporif.Warning: Use only with singleplayer games!", "https://api.github.com/repos/Sporif/dxvk-async/releases", 0, TitleType.NONE));
            tools.append (new Tool ("DXVK Async (gnusenpai)", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch and RTX fix for Star Citizen by gnusenpai.Warning: Use only with singleplayer games!", "https://api.github.com/repos/gnusenpai/dxvk/releases", 0, TitleType.NONE));

            return tools;
        }

        public static GLib.List<Tool> HeroicWine () {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1));
            tools.append (new Tool ("Wine-Lutris", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0));

            return tools;
        }

        public static GLib.List<Tool> HeroicProton () {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool ("Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1));

            return tools;
        }

        public static GLib.List<Tool> Bottles () {
            var tools = new GLib.List<Tool> ();

            tools.append (new Tool ("Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1));
            tools.append (new Tool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1));
            tools.append (new Tool ("Wine-Lutris", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0));

            return tools;
        }
    }
}
