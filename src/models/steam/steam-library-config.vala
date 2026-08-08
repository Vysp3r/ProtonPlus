using Gee;

namespace ProtonPlus.Models.Steam {
    public class SteamLibraryConfig : GLib.Object {
        public ArrayList<LibraryFolder> folders { get; set; }

        public SteamLibraryConfig () {
            this.folders = new ArrayList<LibraryFolder> ();
        }

    }
}
