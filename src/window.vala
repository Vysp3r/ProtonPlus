namespace ProtonPlus {
    public class Window : Adw.ApplicationWindow {
        List<Models.Launcher> launchers;

        int tasks { get; set; }

        Adw.OverlaySplitView overlay_split_view { get; set; }
        Widgets.StatusBox status_box { get; set; }
        Widgets.InfoBox info_box { get; set; }
        Widgets.Sidebar sidebar { get; set; }

        construct {
            //
            this.set_application ((Adw.Application) GLib.Application.get_default ());
            this.set_title (Shared.Constants.APP_NAME);
            this.set_default_size (950, 600);

            //
            this.add_action (load_info_box ());
            this.add_action (add_task ());
            this.add_action (remove_task ());

            //
            this.width_request = 270;
            this.height_request = 45;

            //
            status_box = new Widgets.StatusBox ();

            //
            var info_page = new Adw.NavigationPage.with_tag (info_box = new Widgets.InfoBox (), "InfoBox", "main");

            //
            var sidebar_page = new Adw.NavigationPage.with_tag (sidebar = new Widgets.Sidebar (), "Sidebar", "sidebar");

            //
            sidebar.installed_only_switch.notify["active"].connect(() => {
                info_box.installedOnly = !info_box.installedOnly;
    
                foreach (var container in info_box.containers) {
                    container.box_normal.set_visible (!info_box.installedOnly);
                    container.box_filtered.set_visible (info_box.installedOnly);
                }
            });

            //
            overlay_split_view = new Adw.OverlaySplitView ();
            overlay_split_view.set_sidebar (sidebar_page);
            overlay_split_view.set_content (info_page);
            overlay_split_view.set_max_sidebar_width (270);
            overlay_split_view.set_min_sidebar_width (270);

            //
            overlay_split_view.notify["show-sidebar"].connect(() => {
                info_box.sidebar_button.set_visible (!overlay_split_view.get_show_sidebar ());
            });

            //
            sidebar.sidebar_button.clicked.connect (() => {
                overlay_split_view.set_show_sidebar (!overlay_split_view.get_show_sidebar ());
            });

            //
            info_box.sidebar_button.clicked.connect (() => {
                overlay_split_view.set_show_sidebar (!overlay_split_view.get_show_sidebar ());
            });

            //
            var breakpoint = new Adw.Breakpoint (Adw.BreakpointCondition.parse ("max-width: 625px"));
            breakpoint.add_setter (overlay_split_view, "collapsed", true);

            //
            this.add_breakpoint (breakpoint);
        }

        public override bool close_request () {
            bool busy = tasks > 0;

            if (busy) {
                this.set_visible (false);
                
                this.notify["tasks"].connect(() => {
                    if (tasks == 0) this.close ();
                });
            }

            return busy;
        }

        public void initialize () {
            //
            tasks = 0;

            //
            launchers = Models.Launcher.get_all ();

            //
            if (launchers.length () > 0) {
                //
                info_box.initialize (launchers);
                sidebar.initialize (launchers);

                //
                info_box.switch_launcher (launchers.nth_data (0).title, 0);
                
                //
                if (overlay_split_view.get_parent () == null) {
                    set_content (overlay_split_view);
                }
            } else {
                //
                status_box.initialize (null, _("Welcome to ") + Shared.Constants.APP_NAME, _("Install Steam, Lutris, Bottles or Heroic Games Launcher to get started."));
                
                //
                if (status_box.get_parent () == null) {
                    set_content (status_box);
                }
                
                //
                GLib.Timeout.add (10000, () => {
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
            SimpleAction action = new SimpleAction ("add-task", VariantType.STRING);

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