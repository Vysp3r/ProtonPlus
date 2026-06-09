using GLib;
using Gee;

namespace ProtonPlus.Models.Internal.Data.Runner {
    public class Root : Object {
        public int version { get; set; }
        public Gee.ArrayList<CompatLayerGroup> compat_layers { get; set; }
        public Gee.ArrayList<Launcher> launchers { get; set; }

        public Root () {
            this.compat_layers = new Gee.ArrayList<CompatLayerGroup> ();
            this.launchers = new Gee.ArrayList<Launcher> ();
        }
    }
}