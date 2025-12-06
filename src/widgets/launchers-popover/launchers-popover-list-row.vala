namespace ProtonPlus.Widgets {
	public class LaunchersPopoverListRow : Gtk.ListBoxRow {
		public Models.Launcher launcher;

		public LaunchersPopoverListRow (Models.Launcher launcher) {
			this.launcher = launcher;

			var icon = new Gtk.Image.from_resource (launcher.icon_path);
			icon.set_pixel_size (48);

			var title_label = new Gtk.Label (launcher.title);
			title_label.set_halign (Gtk.Align.START);

			var subtitle_label = new Gtk.Label (launcher.get_installation_type_title ());
			subtitle_label.add_css_class ("dimmed");
			subtitle_label.set_halign (Gtk.Align.START);

			var labels_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			labels_box.set_valign (Gtk.Align.CENTER);
			labels_box.set_hexpand (true);
			labels_box.append (title_label);
			labels_box.append (subtitle_label);

			var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
			content_box.append (icon);
			content_box.append (labels_box);
			content_box.add_css_class ("p-10");

			add_css_class ("card");
			set_tooltip_text (launcher.directory);
			set_activatable (true);
			set_child (content_box);
		}
	}
}
