namespace ProtonPlus.Widgets {
    public class ExtraButton : Gtk.Button {
        Models.Game game { get; set; }
        Gtk.Button start_button { get; set; }
        Gtk.Button open_install_directory_button { get; set; }
        Gtk.Button open_prefix_directory_button { get; set; }
        Gtk.Box content_box { get; set; }
        Gtk.Popover popover { get; set; }

        construct {
            start_button = new Gtk.Button.with_label(_("Start game"));

            open_install_directory_button = new Gtk.Button.with_label(_("Open install directory"));

            open_prefix_directory_button = new Gtk.Button.with_label(_("Open prefix directory"));

            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            content_box.append(start_button);
            content_box.append(open_install_directory_button);
            content_box.append(open_prefix_directory_button);

            popover = new Gtk.Popover();
            popover.set_autohide(true);
            popover.set_parent(this);
            popover.set_child(content_box);
            
            clicked.connect(extra_button_clicked);

            set_icon_name("dots-symbolic");
            set_tooltip_text (_("Extra"));
            add_css_class("flat");
        }

        public ExtraButton (Models.Game game) {
            this.game = game;
        }

        void extra_button_clicked() {
            popover.popup();
        }
    }
}