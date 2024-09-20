namespace ProtonPlus.Widgets {
    public abstract class ReleaseRow : Adw.ActionRow {
        public Gtk.Button btn_remove { get; set; }
        public Gtk.Button btn_install { get; set; }
        public Gtk.Button btn_info { get; set; }
        public Gtk.Box input_box { get; set; }
        public Dialogs.InstallDialog install_dialog { get; set; }
        public Dialogs.RemoveDialog remove_dialog { get; set; }

        internal UIState ui_state { get; set; }
        internal enum UIState {
            // WARNING: `NO_STATE` *MUST* be FIRST entry in this list, to become
            // the "unitialized default value" for Gtk Object properties, since
            // nullable properties aren't allowed for Gtk Objects. You should
            // treat the `NO_STATE` value the same as you would treat `null`.
            NO_STATE,
            BUSY_INSTALLING,
            BUSY_REMOVING,
            UP_TO_DATE,
            UPDATE_AVAILABLE,
            NOT_INSTALLED,
            INSTALLED
        }

        construct {
            install_dialog = new Dialogs.InstallDialog ();

            remove_dialog = new Dialogs.RemoveDialog ();

            btn_remove = new Gtk.Button.from_icon_name ("trash-symbolic");
            btn_remove.set_tooltip_text (_("Delete %s").printf (title));
            btn_remove.add_css_class ("flat");

            btn_install = new Gtk.Button.from_icon_name ("download-symbolic");
            btn_install.set_tooltip_text (_("Install %s").printf (title));
            btn_install.add_css_class ("flat");

            btn_info = new Gtk.Button.from_icon_name ("info-circle-symbolic");
            btn_info.set_tooltip_text (_("Show more information"));
            btn_info.add_css_class ("flat");

            input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            input_box.set_margin_end (10);
            input_box.set_valign (Gtk.Align.CENTER);
            input_box.append (btn_info);
            input_box.append (btn_remove);
            input_box.append (btn_install);

            add_suffix (input_box);
        }
    }
}