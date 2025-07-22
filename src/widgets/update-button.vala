namespace ProtonPlus.Widgets {
	public class UpdateButton : Gtk.Button {
        Adw.Spinner spinner;

        public UpdateButton() {
            spinner = new Adw.Spinner ();

            add_css_class ("flat");
            set_tooltip_text (_("Checking for updates..."));
            set_child (spinner);
        }
	}
}
