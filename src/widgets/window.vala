namespace ProtonPlus.Widgets {
    public class Window : Adw.ApplicationWindow {
        List<Models.Launcher> launchers;

        int tasks { get; set; }

        Adw.OverlaySplitView overlay_split_view { get; set; }
        Widgets.StatusBox status_box { get; set; }
        Widgets.InfoBox info_box { get; set; }
        Widgets.Sidebar sidebar { get; set; }

        construct {
            set_application ((Adw.Application) GLib.Application.get_default ());
            set_title (Constants.APP_NAME);

            add_action (load_info_box ());
            add_action (add_task ());
            add_action (remove_task ());

            // NOTE: Minimum size supported by AdwOverlaySplitView = 272x474,
            // and we have to make our minimum request a bit larger to look nice.
            set_size_request (400, 600);

            status_box = new Widgets.StatusBox ();

            var info_page = new Adw.NavigationPage.with_tag (info_box = new Widgets.InfoBox (), "InfoBox", "main");

            var sidebar_page = new Adw.NavigationPage.with_tag (sidebar = new Widgets.Sidebar (), "Sidebar", "sidebar");

            sidebar.installed_only_switch.notify["active"].connect (() => info_box.installed_only = sidebar.installed_only_switch.active);

            overlay_split_view = new Adw.OverlaySplitView ();
            overlay_split_view.set_sidebar (sidebar_page);
            overlay_split_view.set_content (info_page);
            overlay_split_view.set_max_sidebar_width (270);
            overlay_split_view.set_min_sidebar_width (270);

            overlay_split_view.notify["show-sidebar"].connect (() => info_box.sidebar_button.set_visible (!overlay_split_view.get_show_sidebar ()));

            sidebar.sidebar_button.clicked.connect (() => overlay_split_view.set_show_sidebar (!overlay_split_view.get_show_sidebar ()));

            info_box.sidebar_button.clicked.connect (() => overlay_split_view.set_show_sidebar (!overlay_split_view.get_show_sidebar ()));

            var breakpoint = new Adw.Breakpoint (Adw.BreakpointCondition.parse ("max-width: 625px"));
            breakpoint.add_setter (overlay_split_view, "collapsed", true);

            add_breakpoint (breakpoint);
        }

        public override bool close_request () {
            bool busy = tasks > 0;

            if (busy) {
                set_visible (false);

                notify["tasks"].connect (() => {
                    if (tasks == 0)close ();
                });
            }

            return busy;
        }

        public void initialize () {
            tasks = 0;

            launchers = Models.Launcher.get_all ();

            if (launchers.length () > 0) {
                info_box.initialize (launchers);
                sidebar.initialize (launchers);

                info_box.switch_launcher (launchers.nth_data (0).title, 0);

                if (overlay_split_view.get_parent () == null)
                    set_content (overlay_split_view);
            } else {
                status_box.initialize (null, _("Welcome to %s").printf (Constants.APP_NAME), _("Install Steam, Lutris, Bottles or Heroic Games Launcher to get started."));

                if (status_box.get_parent () == null)
                    set_content (status_box);

                Timeout.add (10000, () => {
                    initialize ();

                    return false;
                });
            }
        }

        SimpleAction load_info_box () {
            SimpleAction action = new SimpleAction ("load-info-box", VariantType.INT32);

            action.activate.connect ((variant) => {
                info_box.switch_launcher (launchers.nth_data (variant.get_int32 ()).title, variant.get_int32 ());
            });

            return action;
        }

        SimpleAction add_task () {
            SimpleAction action = new SimpleAction ("add-tasks", VariantType.STRING);

            action.activate.connect (() => {
                tasks++;
            });

            return action;
        }

        SimpleAction remove_task () {
            SimpleAction action = new SimpleAction ("remove-task", VariantType.STRING);

            action.activate.connect (() => {
                tasks--;
            });

            return action;
        }
    }
}