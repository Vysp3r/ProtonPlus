using GLib;
using Gee;

namespace ProtonPlus.Models.Internal.Data.Runner {
    public class Launcher : Object {
        public string title { get; set; }
        public Gee.ArrayList<LauncherCompatLayer> compat_layers { get; set; }

        public Launcher () {
            this.compat_layers = new Gee.ArrayList<LauncherCompatLayer> ();
        }
    }
}