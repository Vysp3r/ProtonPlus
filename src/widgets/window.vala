namespace ProtonPlus.Widgets {
	public class Window : Adw.ApplicationWindow {
		public bool only_show_used { get; set; }
		public bool only_show_unused { get; set; }
		public bool updating { get; set; }
		List<Models.Launcher> launchers;

		StatusBox status_box;
		RunnersBox runners_box;
		GamesBox games_box;

		LaunchersPopoverButton launchers_popover_button;
		UpdateButton update_button;
		Gtk.Button donate_button;
		Menu menu;
		Gtk.MenuButton menu_button;

		Adw.ViewStack view_stack;
		Adw.ToastOverlay toast_overlay;
		Adw.ViewSwitcher view_switcher;
		Adw.HeaderBar header_bar;
		Adw.ViewSwitcherBar view_switcher_bar;
		Adw.ToolbarView toolbar_view;

		construct {
			set_application ((Adw.Application) GLib.Application.get_default ());
			set_title (Globals.APP_NAME);

			add_action (get_set_selected_launcher_action ());

			status_box = new StatusBox ();

			runners_box = new RunnersBox ();

			games_box = new GamesBox ();

			launchers_popover_button = new LaunchersPopoverButton ();

			update_button = new UpdateButton ();
			update_button.set_visible (false);

			donate_button = new Gtk.Button.from_icon_name ("heart-symbolic");
			donate_button.add_css_class ("red");
			donate_button.set_tooltip_text (_("Donate"));
			donate_button.clicked.connect (donate_button_clicked);

			menu = new Menu ();
			menu.append (_("_Keyboard Shortcuts"), "win.show-help-overlay");
			menu.append (_("_About ProtonPlus"), "app.about");

			menu_button = new Gtk.MenuButton ();
			menu_button.set_tooltip_text (_("Main Menu"));
			menu_button.set_icon_name ("open-menu-symbolic");
			menu_button.set_menu_model (menu);

			view_stack = new Adw.ViewStack ();
			view_stack.add_titled_with_icon (runners_box, "runners", _("Runners"), "system-run-symbolic");
			view_stack.add_titled_with_icon (games_box, "games", _("Games"), "game-library-symbolic");
			view_stack.notify["visible-child-name"].connect (view_stack_visible_child_name_changed);

			toast_overlay = new Adw.ToastOverlay ();
			toast_overlay.set_child (view_stack);

			view_switcher = new Adw.ViewSwitcher ();
			view_switcher.set_stack (view_stack);
			view_switcher.set_policy (Adw.ViewSwitcherPolicy.WIDE);

			header_bar = new Adw.HeaderBar ();
			header_bar.set_title_widget (view_switcher);
			header_bar.pack_start (launchers_popover_button);
			header_bar.pack_start (update_button);
			header_bar.pack_end (menu_button);
			header_bar.pack_end (donate_button);

			view_switcher_bar = new Adw.ViewSwitcherBar ();
			view_switcher_bar.set_stack (view_stack);

			toolbar_view = new Adw.ToolbarView ();
			toolbar_view.add_top_bar (header_bar);
			toolbar_view.set_content (toast_overlay);
			toolbar_view.add_bottom_bar (view_switcher_bar);

			initialize.begin ();
		}

		async void initialize () {
			status_box.initialize ("com.vysp3r.ProtonPlus", _("Loading"), "%s\n%s".printf(_("Taking longer than normal?"), _("Please report this issue on GitHub.")));
			if (status_box.get_parent () == null)
					set_content (status_box);

			yield Globals.load_globals ();

			launchers = yield Models.Launcher.get_all ();

			if (launchers == null) {
				status_box.initialize ("bug-symbolic", _("An error ocurred"), "%s\n%s".printf (_("There was an error when trying to load the launchers."), _("Please report this issue on GitHub.")));

				if (status_box.get_parent () == null)
					set_content (status_box);

				return;
			}

			var valid = launchers.length () > 0;

			if (valid) {
				launchers_popover_button.initialize (launchers);

				if (toolbar_view.get_parent () == null)
					set_content (toolbar_view);

				activate_action_variant ("win.set-selected-launcher", 0);

				update_button.set_visible (true);

				updating = true;

				var toast = new Adw.Toast (_("Checking for updates..."));
				toast_overlay.add_toast (toast);

				Models.Runner.check_for_updates.begin (launchers, (obj, res) => {
					switch (Models.Runner.check_for_updates.end (res)) {
						case Models.Runner.UpdateCodes.NOTHING_FOUND:
							toast.dismiss ();
							toast = new Adw.Toast (_("Nothing to update."));
							break;
						case Models.Runner.UpdateCodes.EVERYTHING_UPDATED:
							toast.dismiss ();
							toast = new Adw.Toast (_("Everything is now up-to-date."));
							break;
						default:
							toast.dismiss ();
							toast = new Adw.Toast (_("An error occured while checking for updates."));
							break;
					}

					toast_overlay.add_toast (toast);

					update_button.set_visible (false);

					updating = false;
				});
			}

			if (!valid) {
				status_box.initialize ("com.vysp3r.ProtonPlus", _("Welcome to %s").printf (Globals.APP_NAME), _("Install Steam, Lutris, Bottles or Heroic Games Launcher to get started."));

				if (status_box.get_parent () == null)
					set_content (status_box);

				Timeout.add (10000, () => {
					initialize.begin ();

					return false;
				});
			}
		}

		void donate_button_clicked () {
			Utils.System.open_uri ("https://protonplus.vysp3r.com/#donate");
		}

		void view_stack_visible_child_name_changed () {
			games_box.active = view_stack.get_visible_child_name () == "games";
		}

		SimpleAction get_set_selected_launcher_action () {
			SimpleAction action = new SimpleAction ("set-selected-launcher", VariantType.INT32);

			action.activate.connect ((variant) => {
				runners_box.set_selected_launcher (launchers.nth_data (variant.get_int32 ()));
				games_box.set_selected_launcher (launchers.nth_data (variant.get_int32 ()));
			});

			return action;
		}

		public override bool close_request () {
			if (!updating) {
				Utils.Filesystem.delete_directory.begin (Globals.DOWNLOAD_CACHE_PATH);

				return false;
			}
				
			var dialog = new Adw.AlertDialog (_("Warning"), _("The application is currently checking for updates.\nExiting the application early may cause issues."));
			
			dialog.add_response ("exit", _("Exit"));
			dialog.set_response_appearance ("exit", Adw.ResponseAppearance.DESTRUCTIVE);

			dialog.add_response ("cancel", _("Cancel"));
			dialog.set_response_appearance ("cancel", Adw.ResponseAppearance.SUGGESTED);

			dialog.set_default_response ("cancel");
			dialog.set_close_response ("cancel");

			dialog.response.connect ((response) => {
				if (response != "exit")
					return;

				Utils.Filesystem.delete_directory.begin (Globals.DOWNLOAD_CACHE_PATH);

				close();
			});

			dialog.present (this);

			return true;
		}
	}
}