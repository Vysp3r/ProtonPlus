namespace ProtonPlus.Models {
    public class Launcher : Object {
        public string Label { public get; private set; }

        public Launcher (string label) {
            this.Label = label;
        }

        public static Gtk.ListStore GetModel () {
            Gtk.ListStore model = new Gtk.ListStore (2, typeof (string), typeof (Launcher));
            Gtk.TreeIter iter;

            foreach (var item in All ()) {
                model.append (out iter);
                model.set (iter, 0, item.Label, 1, item, -1);
            }

            return model;
        }

        public static Launcher[] All () {
            Launcher[] launchers = new Launcher[5];

            launchers[0] = new Launcher ("Steam");
            launchers[1] = new Launcher ("Lutris");
            launchers[2] = new Launcher ("Heroic Wine");
            launchers[3] = new Launcher ("Heroic Proton");
            launchers[4] = new Launcher ("Bottles");

            return launchers;
        }
    }
}
