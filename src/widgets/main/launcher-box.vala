namespace ProtonPlus.Widgets {
	public class LauncherBox : Gtk.Widget {
		Models.Launcher launcher { get; set; }
		Gtk.BinLayout bin_layout { get; set; }
		Gtk.Box content { get; set; }
		Adw.Clamp clamp { get; set; }
		Gtk.ScrolledWindow scrolled_window { get; set; }
		List<RunnerGroup> runner_groups;

		public LauncherBox () {
			set_vexpand (true);
			set_margin_start (15);
			set_margin_end (15);
			set_margin_bottom (15);

			bin_layout = new Gtk.BinLayout ();
			set_layout_manager (bin_layout);

			content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);

			clamp = new Adw.Clamp ();
			clamp.set_maximum_size (700);
			clamp.set_child (content);

			scrolled_window = new Gtk.ScrolledWindow ();
			scrolled_window.set_child (clamp);
			scrolled_window.set_parent (this);
		}

		public void load (Models.Launcher launcher, bool installed_only) {
			this.launcher = launcher;

			foreach (var runner_group in runner_groups) {
				content.remove (runner_group);
			}

			runner_groups = new List<RunnerGroup> ();

			foreach (var group in launcher.groups) {
				var runner_group = new RunnerGroup (group, installed_only);
				runner_groups.append (runner_group);
				content.append (runner_group);
			}
		}

		public void switch_mode (bool mode) {
			foreach (var runner_group in runner_groups) {
				runner_group.load (mode);
			}
		}
	}
}
