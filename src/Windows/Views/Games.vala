namespace Windows.Views {
    public class Games : Gtk.Box {
        public Games () {
            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (15);
            set_margin_bottom (15);
            set_margin_end (15);
            set_margin_start (15);
            set_margin_top (15);

            append (new Gtk.Label ("WIP"));
        }
    }
}
