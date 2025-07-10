namespace ProtonPlus.Widgets {
	public class DefaultToolButton : Gtk.Button {
		Adw.ButtonContent default_tool_button_content { get; set; }
		Models.Launchers.Steam launcher { get; set; }

		construct {
			default_tool_button_content = new Adw.ButtonContent();
			default_tool_button_content.set_label(_("Set the default compatibility tool"));
			default_tool_button_content.set_icon_name("carambola-symbolic");

			clicked.connect(default_tool_button_clicked);

			set_icon_name("dots-symbolic");
			set_tooltip_text(_("Set the default compatibility tool"));
			set_child(default_tool_button_content);
			add_css_class("flat");
		}

		public void load(Models.Launchers.Steam launcher) {
			this.launcher = launcher;
		}

		void default_tool_button_clicked() {
			var dialog = new DefaultToolDialog(launcher);
			dialog.present(Application.window);
		}
	}
}
