namespace ProtonPlus.Widgets {
	public abstract class ReleaseRow : Adw.ActionRow {
		protected Gtk.Button open_button { get; set; }
		protected Gtk.Button install_button { get; set; }
		protected Gtk.Button remove_button { get; set; }
		protected Gtk.Button info_button { get; set; }
		protected Gtk.Box input_box { get; set; }

		construct {
			open_button = new Gtk.Button.from_icon_name ("folder-symbolic");
			open_button.set_tooltip_text (_("Open runner directory"));
			open_button.add_css_class ("flat");

			info_button = new Gtk.Button.from_icon_name ("info-circle-symbolic");
			info_button.set_tooltip_text (_("Show more information"));
			info_button.add_css_class ("flat");

			remove_button = new Gtk.Button.from_icon_name ("trash-symbolic");
			remove_button.set_tooltip_text (_("Delete %s").printf (title));
			remove_button.add_css_class ("flat");

			install_button = new Gtk.Button.from_icon_name ("download-symbolic");
			install_button.set_tooltip_text (_("Install %s").printf (title));
			install_button.add_css_class ("flat");

			input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
			input_box.set_margin_end (10);
			input_box.set_valign (Gtk.Align.CENTER);
			input_box.append (open_button);
			input_box.append (info_button);
			input_box.append (remove_button);
			input_box.append (install_button);

			add_suffix (input_box);

			open_button.clicked.connect (open_button_clicked);
			install_button.clicked.connect (install_button_clicked);
			remove_button.clicked.connect (remove_button_clicked);
			info_button.clicked.connect (info_button_clicked);

			Application.window.notify["only-show-used"].connect(only_show);
			Application.window.notify["only-show-unused"].connect(only_show);
		}

		internal void only_show () {
			if (Application.window.only_show_used) {
				set_visible (get_title().contains("(%s)".printf(_("Used"))));
			} else if (Application.window.only_show_unused) {
				set_visible (!get_title().contains("(%s)".printf(_("Used"))));
			} else {
				set_visible (true);
			}
		}

		protected abstract void open_button_clicked ();

		protected abstract void install_button_clicked ();

		protected abstract void remove_button_clicked ();

		protected abstract void info_button_clicked ();
	}
}
