namespace ProtonPlus.Widgets {
    public abstract class ReleaseRow : Adw.ActionRow {
        protected Gtk.Button install_button { get; set; }
        protected Gtk.Button remove_button { get; set; }
        protected Gtk.Button info_button { get; set; }
        protected Gtk.Box input_box { get; set; }
        protected Dialogs.InstallDialog install_dialog { get; set; }
        protected Dialogs.RemoveDialog remove_dialog { get; set; }

        construct {
            install_dialog = new Dialogs.InstallDialog ();

            remove_dialog = new Dialogs.RemoveDialog ();

            remove_button = new Gtk.Button.from_icon_name ("trash-symbolic");
            remove_button.set_tooltip_text (_("Delete %s").printf (title));
            remove_button.add_css_class ("flat");

            install_button = new Gtk.Button.from_icon_name ("download-symbolic");
            install_button.set_tooltip_text (_("Install %s").printf (title));
            install_button.add_css_class ("flat");

            info_button = new Gtk.Button.from_icon_name ("info-circle-symbolic");
            info_button.set_tooltip_text (_("Show more information"));
            info_button.add_css_class ("flat");

            input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            input_box.set_margin_end (10);
            input_box.set_valign (Gtk.Align.CENTER);
            input_box.append (info_button);
            input_box.append (remove_button);
            input_box.append (install_button);

            add_suffix (input_box);

            install_button.clicked.connect (install_button_clicked);
            remove_button.clicked.connect (remove_button_clicked);
            info_button.clicked.connect (info_button_clicked);
        }

        protected abstract void install_button_clicked ();

        protected abstract void remove_button_clicked ();

        protected abstract void info_button_clicked ();
    }
}