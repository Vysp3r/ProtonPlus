namespace ProtonPlus.Widgets {
    public class Window : Adw.ApplicationWindow {
        List<Models.Launcher> launchers;

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

            add_action (set_nav_view_active ());
            add_action (load_info_box ());
            add_action (set_installed_only ());

            set_size_request (460, 600);

            status_box = new Widgets.StatusBox ();

            info_page = new Adw.NavigationPage.with_tag (info_box = new Widgets.InfoBox (), "InfoBox", "main");

            sidebar_page = new Adw.NavigationPage.with_tag (sidebar = new Widgets.Sidebar (), "Sidebar", "sidebar");

            navigation_split_view = new Adw.NavigationSplitView ();
            navigation_split_view.set_sidebar (sidebar_page);
            navigation_split_view.set_content (info_page);
            navigation_split_view.set_show_content (true);

            breakpoint = new Adw.Breakpoint (Adw.BreakpointCondition.parse ("max-width: 660px"));
            breakpoint.add_setter (navigation_split_view, "collapsed", true);

            add_breakpoint (breakpoint);
        }

        public void initialize () {
            launchers = Models.Launcher.get_all ();

            if (launchers.length () > 0) {
                info_box.initialize (launchers);
                sidebar.initialize (launchers);

                if (navigation_split_view.get_parent () == null)
                    set_content (navigation_split_view);
            } else {
                status_box.initialize (null, _("Welcome to %s").printf (Config.APP_NAME), _("Install Steam, Lutris, Bottles or Heroic Games Launcher to get started."));

                if (status_box.get_parent () == null)
                    set_content (status_box);

                Timeout.add (10000, () => {
                    initialize ();

                    return false;
                });
            }
        }

        SimpleAction set_installed_only () {
            SimpleAction action = new SimpleAction.stateful ("set-installed-only", VariantType.BOOLEAN, true);

            action.activate.connect ((variant) => {
                action.set_state (!action.get_state ().get_boolean ());
                info_box.switch_mode (!action.get_state ().get_boolean ());
            });

            return action;
        }

        SimpleAction set_nav_view_active () {
            SimpleAction action = new SimpleAction ("set-nav-view-active", VariantType.BOOLEAN);

            action.activate.connect ((variant) => {
                navigation_split_view.set_show_content (variant.get_boolean ());
            });

            return action;
        }

        SimpleAction load_info_box () {
            SimpleAction action = new SimpleAction ("load-info-box", VariantType.INT32);

            action.activate.connect ((variant) => {
                info_box.switch_launcher (launchers.nth_data (variant.get_int32 ()).title, variant.get_int32 ());
            });

            return action;
        }
    }
}