namespace ProtonPlus.Widgets {
    public class Window : Adw.ApplicationWindow {
        List<Models.Launcher> launchers;
        Models.Launcher selected_launcher { get; set; }
        bool installed_only { get; set; }

        Adw.NavigationView navigation_view { get; set; }
        Adw.NavigationPage runners_page { get; set; }
        LibraryBox library_box { get; set; }
        Adw.NavigationPage games_page { get; set; }
        Adw.NavigationSplitView navigation_split_view { get; set; }
        Adw.NavigationPage info_page { get; set; }
        Adw.NavigationPage sidebar_page { get; set; }
        Widgets.StatusBox status_box { get; set; }
        Widgets.InfoBox info_box { get; set; }
        Widgets.Sidebar sidebar { get; set; }
        Adw.Breakpoint breakpoint { get; set; }

        construct {
            set_application ((Adw.Application) GLib.Application.get_default ());
            set_title (Config.APP_NAME);

            add_action (get_set_libray_active_action ());
            add_action (get_set_nav_view_active_action ());
            add_action (get_set_selected_launcher_action ());
            add_action (get_set_installed_only_action ());

            set_size_request (1024, 600);

            status_box = new Widgets.StatusBox ();

            info_page = new Adw.NavigationPage.with_tag (info_box = new Widgets.InfoBox (), "x", "main");

            sidebar_page = new Adw.NavigationPage.with_tag (sidebar = new Widgets.Sidebar (), _("Show sidebar"), "sidebar");

            navigation_split_view = new Adw.NavigationSplitView ();
            navigation_split_view.set_sidebar (sidebar_page);
            navigation_split_view.set_content (info_page);
            navigation_split_view.set_show_content (true);

            library_box = new LibraryBox ();

            runners_page = new Adw.NavigationPage.with_tag (navigation_split_view, _("Go back"), "runners");

            games_page = new Adw.NavigationPage.with_tag (library_box, "y", "games");

            navigation_view = new Adw.NavigationView ();
            navigation_view.push (runners_page);

            breakpoint = new Adw.Breakpoint (Adw.BreakpointCondition.parse ("max-width: 660px"));
            breakpoint.add_setter (navigation_split_view, "collapsed", true);

            add_breakpoint (breakpoint);
        }

        public void initialize () {
            launchers = Models.Launcher.get_all ();

            if (launchers.length () > 0) {
                activate_action_variant ("win.set-selected-launcher", 0);

                sidebar.initialize (launchers);

                if (navigation_view.get_parent () == null)
                    set_content (navigation_view);
            } else {
                status_box.initialize ("com.vysp3r.ProtonPlus", _("Welcome to %s").printf (Config.APP_NAME), _("Install Steam, Lutris, Bottles or Heroic Games Launcher to get started."));

                if (status_box.get_parent () == null)
                    set_content (status_box);

                Timeout.add (10000, () => {
                    initialize ();

                    return false;
                });
            }
        }

        SimpleAction get_set_libray_active_action () {
            SimpleAction action = new SimpleAction ("set-library-active", VariantType.INT32);

            action.activate.connect ((variant) => {
                var launcher = launchers.nth_data (variant.get_int32 ());
                if (launcher.has_library_support) {
                    library_box.load (launcher);
                    navigation_view.push (games_page);
                }
            });

            return action;
        }

        SimpleAction get_set_installed_only_action () {
            SimpleAction action = new SimpleAction.stateful ("set-installed-only", VariantType.BOOLEAN, true);

            action.activate.connect ((variant) => {
                installed_only = action.get_state ().get_boolean ();
                action.set_state (!action.get_state ().get_boolean ());
                info_box.switch_mode (!action.get_state ().get_boolean ());
            });

            return action;
        }

        SimpleAction get_set_nav_view_active_action () {
            SimpleAction action = new SimpleAction ("set-nav-view-active", VariantType.BOOLEAN);

            action.activate.connect ((variant) => {
                navigation_split_view.set_show_content (variant.get_boolean ());
            });

            return action;
        }
        

        SimpleAction get_set_selected_launcher_action () {
            SimpleAction action = new SimpleAction ("set-selected-launcher", VariantType.INT32);

            action.activate.connect ((variant) => {
                selected_launcher = launchers.nth_data (variant.get_int32 ());
                info_box.load (selected_launcher, installed_only);
            });

            return action;
        }
    }
}