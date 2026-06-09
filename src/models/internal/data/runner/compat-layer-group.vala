using GLib;
using Gee;

namespace ProtonPlus.Models.Internal.Data.Runner {
    public class CompatLayerGroup : Object {
        public string title { get; set; }
        public string description { get; set; }
        public Gee.ArrayList<Runner> runners { get; set; }

        public CompatLayerGroup () {
            this.runners = new Gee.ArrayList<Runner> ();
        }
    }
}