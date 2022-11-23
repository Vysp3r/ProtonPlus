namespace ProtonPlus.Models {
    public class Tool : Object {

        public string Title { public get; private set; }
        public string Description { public get; private set; }
        public string Endpoint { public get; private set; }
        public int AssetPosition { public get; private set; }

        public Tool (string title, string description, string endpoint, int asset_position) {
            this.Title = title;
            this.Description = description;
            this.Endpoint = endpoint;
            this.AssetPosition = asset_position;
        }

        public static GLib.ListStore GetStore (Tool[] tools) {
            var store = new GLib.ListStore (typeof (Tool));

            foreach (var tool in tools) {
                store.append (tool);
            }

            return store;
        }

        public static Tool[] Steam () {
            var tools = new Tool[6];

            tools[0] = new Tool ("Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1);
            tools[1] = new Tool ("Proton Tkg", "Custom Proton build for running Windows games, built with the Wine-tkg build system.", "https://api.github.com/repos/Frogging-Family/wine-tkg-git/releases", 1);
            tools[2] = new Tool ("Luxtorpeda", "Luxtorpeda provides Linux-native game engines for specific Windows-only games.", "https://api.github.com/repos/luxtorpeda-dev/luxtorpeda/releases", 0);
            tools[3] = new Tool ("Boxtron", "Steam Play compatibility tool to run DOS games using native Linux DOSBox.", "https://api.github.com/repos/dreamer/boxtron/releases", 0);
            tools[4] = new Tool ("Roberta", "Steam Play compatibility tool to run adventure games using native Linux ScummVM.", "https://api.github.com/repos/dreamer/roberta/releases", 1);
            tools[5] = new Tool ("NorthstarProton", "Custom Proton build for running the Northstar client for Titanfall 2.", "https://api.github.com/repos/cyrv6737/NorthstarProton/releases", 0);

            return tools;
        }

        public static Tool[] Lutris () {
            var tools = new Tool[3];

            tools[0] = new Tool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1);
            tools[1] = new Tool ("Wine-Lutris", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0);
            tools[2] = new Tool ("Kron4ek Wine-Builds Vanilla", "Compatibility tool \"Wine\" to run Windows games on Linux. Official version from the WineHQ sources, compiled by Kron4ek.", "https://api.github.com/repos/Kron4ek/Wine-Builds/releases", 5);

            return tools;
        }

        public static Tool[] LutrisDXVK () {
            var tools = new Tool[3];

            tools[0] = new Tool ("DXVK", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine.https://github.com/lutris/docs/blob/master/HowToDXVK.md", "https://api.github.com/repos/doitsujin/dxvk/releases", 0);
            tools[1] = new Tool ("DXVK Async (Sporif)", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch by Sporif.Warning: Use only with singleplayer games!", "https://api.github.com/repos/Sporif/dxvk-async/releases", 0);
            tools[2] = new Tool ("DXVK Async (gnusenpai)", "Vulkan based implementation of Direct3D 9, 10 and 11 for Linux/Wine with async patch and RTX fix for Star Citizen by gnusenpai.Warning: Use only with singleplayer games!", "https://api.github.com/repos/gnusenpai/dxvk/releases", 0);

            return tools;
        }

        public static Tool[] HeroicWine () {
            var tools = new Tool[2];

            tools[0] = new Tool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1);
            tools[1] = new Tool ("Wine-Lutris", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0);

            return tools;
        }

        public static Tool[] HeroicProton () {
            var tools = new Tool[1];

            tools[0] = new Tool ("Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1);

            return tools;
        }

        public static Tool[] Bottles () {
            var tools = new Tool[3];

            tools[0] = new Tool ("Proton-GE", "Steam compatibility tool for running Windows games with improvements over Valve's default Proton. Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases", 1);
            tools[1] = new Tool ("Wine-GE", "Compatibility tool \"Wine\" to run Windows games on Linux. Based on Valve Proton Experimental's bleeding-edge Wine, built for Lutris.Use this when you don't know what to choose.", "https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases", 1);
            tools[2] = new Tool ("Wine-Lutris", "Compatibility tool \"Wine\" to run Windows games on Linux. Improved by Lutris to offer better compatibility or performance in certain games.", "https://api.github.com/repos/lutris/wine/releases", 0);

            return tools;
        }
    }
}

