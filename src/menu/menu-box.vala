namespace ProtonPlus.Menu {
    public class MenuBox : Gtk.Box {
        public Adw.ApplicationWindow window { get; construct; }

        public MenuBox (Adw.ApplicationWindow window) {
            Object (window: window);
        }

        construct {
            //
            this.set_orientation (Gtk.Orientation.VERTICAL);

            //
            var back_btn = new Gtk.Button.from_icon_name ("go-previous-symbolic");
            back_btn.clicked.connect (() => this.activate_action_variant ("win.switch-other-page", 0));

            //
            var title = new Adw.WindowTitle ("", "");

            //
            var header = new Adw.HeaderBar ();
            header.set_title_widget (title);
            header.pack_start (back_btn);

            //
            var about_row = new Adw.ActionRow ();
            about_row.set_title ("About");
            about_row.set_activatable (true);
            about_row.activated.connect (() => this.activate_action ("app.about", ""));

            //
            var group = new Adw.PreferencesGroup ();
            group.add (about_row);

            //
            var clamp = new Adw.Clamp ();
            clamp.set_margin_top (15);
            clamp.set_margin_bottom (15);
            clamp.set_margin_start (15);
            clamp.set_margin_end (15);
            clamp.set_maximum_size (750);
            clamp.set_child (group);

            //
            append (header);
            append (clamp);
        }
    }
}