namespace ProtonPlus.Views {
    public class Games {
        public static Gtk.Box GetBox () {
            var boxMain = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            boxMain.append (new Gtk.Label ("WIP"));

            return boxMain;
        }
    }
}
